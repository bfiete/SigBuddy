using System;
using System.IO;
using System.Collections;
using System.Diagnostics;

namespace SigBuddy;

class VCDFormat : WaveFormat
{
	struct VarData
	{
		public StringView mKind;
		public int32 mNumBits;
		public int32 mID;
		public StringView mName;
		public StringView mDims;
	}

	enum State
	{
		case None;
		case Unknown;
		case Comment;
		case Scope(int32 dataIdx);
		case Var(int32 dataIdx);
		case Timescale;
	}

	SigData mSigData;

	public this(SigData sigData)
	{
		mSigData = sigData;
	}

	public override Result<void> Load(StringView filePath)
	{
		UnbufferedFileStream fs = scope .();
		if (fs.Open(filePath, .Read) case .Err)
			return .Err;

		mSigData.mRoot = new .();

		int32 chunkSize = 1024 * 1024;

		char8* data = new char8[chunkSize + 8 * 2]*;
		defer delete data;

		// Terminate chunk with sequence that will reduce paring special cases
		for (int i < 8)
		{
			data[chunkSize + i * 2] = 0;
			data[chunkSize + i * 2 + 1] = '?';
		}

		State parseState = .None;
		VarData varData = default;
		List<SignalData> signalDataMap = scope .();
		defer
		{
			for (var signalData in signalDataMap)
				signalData?.ReleaseRef();
		}

		List<SignalGroup> signalGroupStack = scope .();
		signalGroupStack.Add(mSigData.mRoot);

		//int64 totalLen = fs.Length;

		String timescaleStr = scope .();

		uint32[4096] tempBuf = ?;
		int32 parseIdx = 0;
		int totalReadLen = 0;

		int64 tick = 0;
		bool isFirstTick = true;
		int32 carryoverSize = 0;
		while (true)
		{
			int readLen = 0;
			switch (fs.TryRead(.((.)data + carryoverSize, chunkSize - carryoverSize)))
			{
			case .Ok(out readLen):
			case .Err:
				return .Err;
			}
			totalReadLen += readLen;

			int32 dataLen = (.)readLen + carryoverSize;
			bool atEnd = false;

			void FindEnd()
			{
				if (dataLen == chunkSize)
				{
					// Zero terminate on the last line ending
					char8* checkPtr = data + dataLen - 1;
					while (checkPtr > data)
					{
						if (*checkPtr == '\n')
							break;
						checkPtr--;
					}

					*(checkPtr) = 0;
				}
				else
				{
					Debug.Assert(dataLen < chunkSize);
					atEnd = true;
					// Force a \n at the end just to ensure the 'null' terminator occurs at a line start
					data[dataLen] = '\n';
					data[dataLen + 1] = 0;
				}
			}

			FindEnd();

			char8* curPtr = data;

			//Debug.WriteLine($"Processing:\n{StringView(curPtr)}\n");

			StringView NextString()
			{
				// Find string start
				while (true)
				{
					char8 c = *curPtr;
					if (c > ' ')
						break;
					curPtr++;
				}

				char8* startPtr = curPtr;

				while (true)
				{
					char8 c = *curPtr;
					if (c <= ' ')
						break;
					curPtr++;
				}

				return .(startPtr, curPtr - startPtr);
			}

			// Read header
			while (true)
			{
				parseIdx++;

				char8 c = *curPtr;
				if (c == 0)
					break;

				if (parseState == .None)
				{
					if (c <= ' ') // Ignore whitespace
					{
						curPtr++;
						continue;
					}
					if (c == '#')
					{
						curPtr++;

						int64 newTick = 0;
						while (true)
						{
							c = *curPtr;
							if (c <= ' ')
								break;
							newTick *= 10;
							newTick += c - '0';
							curPtr++;
						}

						if (isFirstTick)
						{
							mSigData.mStartTick = newTick;
							isFirstTick = false;
						}
						Debug.Assert(newTick >= tick);
						tick = newTick;
						mSigData.mEndTick = tick;

						continue;
					}

					bool hasDataBits = false;
					bool needsDataBits = false;
					char8* startValPtr = null;

					if (c == 'b')
					{
						curPtr++;

						startValPtr = curPtr;
						while (true)
						{
							c = *curPtr;
							if (c <= ' ')
								break;
							curPtr++;
						}
						needsDataBits = true;
					}
					else if (c == '0')
					{
						tempBuf[0] = 0;
						hasDataBits = true;
						curPtr++;
					}
					else if (c == '1')
					{
						tempBuf[0] = 1;
						hasDataBits = true;
						curPtr++;
					}
					else if (c == 'x')
					{
						tempBuf[0] = 2;
						hasDataBits = true;
						curPtr++;
					}
					else if (c == 'z')
					{
						tempBuf[0] = 3;
						hasDataBits = true;
						curPtr++;
					}

					if ((hasDataBits) || (needsDataBits))
					{
						char8* scanPtr = curPtr - 1;

						int32 dataId = 0;
						while (*curPtr <= ' ')
							curPtr++;

						while (true)
						{
							c = *curPtr;
							if (c <= ' ')
								break;

							curPtr++;
							// Id range is from \x33 to \x126
							dataId *= 95;
							dataId += (uint8)c - 32;
						}

						if ((dataId >= 0) && (dataId < signalDataMap.[Friend]mSize))
						{
							var signalData = signalDataMap[dataId];
							if (signalData != null)
							{
								int numSignalBits = signalData.mNumBits;

								if (isFirstTick)
								{
									mSigData.mStartTick = tick;
									isFirstTick = false;
								}

								if (needsDataBits)
								{
									if (numSignalBits <= 16)
									{
										tempBuf[0] = 0;

										if (numSignalBits == scanPtr - startValPtr + 1)
										{
											for (int bitNum < numSignalBits)
											{
												c = *(scanPtr--);
												uint32 bitVal = ((uint32)c & 1) | (((uint32)c >> 1) & 1) | (((uint32)c >> 2) & 2);
												tempBuf[0] |= bitVal << (bitNum * 2);
											}
										}
										else
										{
											uint32 bitVal = 0;
											for (int bitNum < numSignalBits)
											{
												if (scanPtr >= startValPtr)
												{
													c = *(scanPtr--);
													bitVal = ((uint32)c & 1) | (((uint32)c >> 1) & 1) | (((uint32)c >> 2) & 2);
												}
												else if (bitVal == 1)
													bitVal = 0;
												tempBuf[0] |= bitVal << (bitNum  * 2);
											}
										}
									}
									else
									{
										for (int i < (numSignalBits + 15)/16)
											tempBuf[i] = 0;

										uint32 bitVal = 0;
										for (int bitNum < numSignalBits)
										{
											if (scanPtr >= startValPtr)
											{
												c = *(scanPtr--);
												/*if (c == '1')
													bitVal = 1;
												else if (c == 'x')
													bitVal = 2;
												else if (c == 'z')
													bitVal = 3;
												else
													bitVal = 0;*/

												// Bitwise version of the above
												bitVal = ((uint32)c & 1) | (((uint32)c >> 1) & 1) | (((uint32)c >> 2) & 2);
											}
											else if (bitVal == 1)
												bitVal = 0;

											tempBuf[bitNum / 16] |= bitVal << ((bitNum % 16) * 2);
										}
									}
								}

								signalData.Encode(tick, &tempBuf);
							}
						}
						else
						{
							Debug.FatalError("Invalid id");
						}

						continue;
					}
				}

				switch (parseState)
				{
				case .None:
					var s = NextString();
					switch (s)
					{
					case "$comment":
						parseState = .Comment;
					case "$var":
						varData = default;
						parseState = .Var(0);
					case "$scope":
						var signalGroup = new SignalGroup();
						
						var curGroup = signalGroupStack.Back;
						if (curGroup.mNestedGroups == null)
						{
							curGroup.mNestedGroups = new .();
							curGroup.mGroupMap = new .();
						}
						curGroup.mNestedGroups.Add(signalGroup);
						signalGroup.mGroup = curGroup;
						
						signalGroupStack.Add(signalGroup);
						parseState = .Scope(0);
					case "$upscope":
						if (!signalGroupStack.IsEmpty)
							signalGroupStack.PopBack();
					case "$timescale":
						timescaleStr.Clear();
						parseState = .Timescale;
					case "$enddefinitions":
					case "$dumpvars":
						// Don't do anything
					case "$dumpall":
						// Don't do anything
					case "$end":
						// Don't do anything
					default:
						if (s.StartsWith('$'))
							parseState = .Unknown;
					}
				case .Comment:
					var str = NextString();
					if (str == "$end")
					{
						parseState = .None;
						break;
					}
				case .Unknown:
					var str = NextString();
					if (str == "$end")
					{
						parseState = .None;
						break;
					}
				case .Scope(let dataIdx):
					var str = NextString();
					if (str == "$end")
					{
						var signalGroup = signalGroupStack.Back;
						if (signalGroup.mGroup != null)
							signalGroup.mGroup.mGroupMap[signalGroup.mName] = signalGroup;

						parseState = .None;
						break;
					}

					switch (dataIdx)
					{
					case 0:
						// Todo: check against 'module'?
					case 1:
						signalGroupStack.Back.mName.Set(str);
					}

					parseState = .Scope(dataIdx + 1);
				case .Timescale:
					var str = NextString();
					if (str == "$end")
					{
						double scale = 0;
						int scaleLen = 2;

						if (timescaleStr.EndsWith("ms"))
							scale = 1e-3;
						else if (timescaleStr.EndsWith("us"))
							scale = 1e-6;
						else if (timescaleStr.EndsWith("ns"))
							scale = 1e-9;
						else if (timescaleStr.EndsWith("ps"))
							scale = 1e-12;
						else if (timescaleStr.EndsWith("fs"))
							scale = 1e-15;
						else if (timescaleStr.EndsWith("s"))
						{
							scale = 1;
							scaleLen = 1;
						}	

						if (scale != 0)
						{
							if (double.Parse(timescaleStr.Substring(0, timescaleStr.Length - scaleLen)) case .Ok(var val))
							{
								mSigData.mTimescale = val * scale;
							}
						}

						parseState = .None;
						break;
					}
					timescaleStr.Append(str);
				case .Var(let dataIdx):
					var str = NextString();
					if (str == "$end")
					{
						if (!signalGroupStack.IsEmpty)
						{
							// ID sanity check
							if (varData.mID < 1024 * 1024)
							{
								if (signalDataMap.Count <= varData.mID)
									signalDataMap.Resize(varData.mID + 1);
								if (signalDataMap[varData.mID] == null)
								{
									var signalData = new SignalData(varData.mNumBits);
									signalDataMap[varData.mID] = signalData;
								}

								var signalGroup = signalGroupStack.Back;

								Signal signal = new Signal();
								if (varData.mKind == "reg")
									signal.mKind = .Reg;
								else if (varData.mKind == "parameter")
									signal.mKind = .Parameter;
								signal.mGroup = signalGroup;

								signal.mName = new .(varData.mName);
								if (!varData.mDims.IsEmpty)
									signal.mDims = new .(varData.mDims);
								signal.mSignalData = signalDataMap[varData.mID]..AddRef();
								signalGroup.mSignals.Add(signal);
								signalGroup.mSignalMap[signal.mName] = signal;
							}
						}

						parseState = .None;
						break;
					}

					switch (dataIdx)
					{
					case 0:
						varData.mKind = str;
					case 1:
						varData.mNumBits = int32.Parse(str).GetValueOrDefault();
					case 2:
						if (str.Length == 1)
						{
							varData.mID = *(uint8*)str.Ptr - 32;
						}
						else
						{
							for (int i < str.Length)
							{
								// Id range is from \x33 to \x126
								varData.mID *= 95;
								varData.mID += (uint8)str[i] - 32;
							}
						}
					case 3:
						varData.mName = str;
					case 4:
						varData.mDims = str;
					}
					parseState = .Var(dataIdx + 1);
				default:
				}
			}

			if (atEnd)
				break;

			carryoverSize = (.)((data + dataLen) - curPtr - 1);
			if (carryoverSize < 0)
			{
				carryoverSize = 0;
			}
			else if (carryoverSize > 0)
			{
				Internal.MemMove(data, data + dataLen - carryoverSize, carryoverSize);
			}
		}

		mSigData.mRoot.Finish();

		return .Ok;
	}
}
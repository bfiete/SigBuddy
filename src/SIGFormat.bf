#pragma warning disable 168
using System.IO;
using System.Collections;
using System;
namespace SigBuddy;

class SIGFormat : WaveFormat
{
	enum SigCmd
	{
		None,
	    DeclareSignal,
	    TimeDelta8,
	    TimeDelta16,
	    TimeDelta32,
	    TimeDelta64,
	    Code8,
	    Code16,
	    Code32,
	    Code64,
	    ValZero,
	    ValOne,
	    ValNegOne,
		Val8,
		Val16,
		Val32,
		Val64,
	    ValX,
		CodeValZero8,
	    CodeValZero16,
	    CodeValZero32,
	    CodeValZero64,
		CodeValOne8,
	    CodeValOne16,
	    CodeValOne32,
	    CodeValOne64,
		CodeSetString
	};

	enum SigFlags
	{
	    None,
	    Tri,
	    Bussed,
	};

	SigData mSigData;

	public this(SigData sigData)
	{
		mSigData = sigData;
	}

	public override System.Result<void> Load(System.StringView filePath)
	{
		int endPad = 16;
		List<uint8> fileData = scope .();

		// Presize buffer with padding
		{
			FileStream fs = scope .();
			if (fs.Open(filePath, .Read, .ReadWrite) case .Ok)
			{
				fileData.Reserve(fs.Length + endPad);
			}
		}
		
		if (File.ReadAll(filePath, fileData) case .Err)
			return .Err;

		int fileSize = fileData.Count;

		// Pad end
		fileData.Resize(fileData.Count + endPad); 

		uint8* startPtr = fileData.Ptr;
		uint8* ptr = startPtr;
		uint8* endPtr = fileData.Ptr + fileSize;

		bool CheckRead(int32 size)
		{
			return ptr + size <= endPtr;
		}

		T Read<T>()
		{
			T val = *(T*)ptr;
			ptr += sizeof(T);
			return val;
		}

		bool Read(String str)
		{
			int32 len = Read<int32>();
			if (len < 0)
				return false;
			if (!CheckRead(len))
				return false;
			str.Append(StringView((.)ptr, len));
			ptr += len;
			return true;
		}

		/*UnbufferedFileStream fs = scope .();
		if (fs.Open(filePath, .Read) case .Err)
			return .Err;*/

		uint32 sig = Read<uint32>();
		if (sig != 0x42474953) // SIGB
			return .Err;

		uint32 version = Read<uint32>();
		if (version == 0)
			return .Err;
		if (version > 1)
			return .Err;

		double timeRes = Read<double>();
		double timeUnit = Read<double>();
		mSigData.mTimescale = timeRes;

		mSigData.mRoot = new .();
		mSigData.mRoot.mNestedGroups = new .();
		mSigData.mRoot.mGroupMap = new .();

		var topGroup = new SignalGroup();
		topGroup.mGroup = mSigData.mRoot;
		topGroup.mName.Set("TOP");
		mSigData.mRoot.mNestedGroups.Add(topGroup);
		mSigData.mRoot.mGroupMap[topGroup.mName] = topGroup;

		uint32[4096] dataBuffer = ?;
		bool isFirstTick = false;

		int64 tick = 0;
		int32 curCode = 0;

		SignalData curSignalData = null;

		List<SignalData> signalDataMap = scope List<SignalData>();

		void AddTick(int64 tickOfs)
		{
			tick += tickOfs;
			if (isFirstTick)
			{
				mSigData.mStartTick = tickOfs;
				isFirstTick = false;
			}
		}

		void SelectSignal(int64 sigNum)
		{
			if ((sigNum >= 0) && (sigNum < signalDataMap.Count))
				curSignalData = signalDataMap[sigNum];
		}

		void RecordSignal(uint32* data, int numBytes)
		{
			if (curSignalData == null)
				return;

			dataBuffer[0] = 0;
			if (curSignalData.mNumBits > 16)
			{
				for (int i < (curSignalData.mNumBits + 15)/16)
					dataBuffer[i] = 0;
			}

			for (int i < numBytes)
			{
				var b = ((uint8*)data)[i];
				((uint16*)&dataBuffer)[i] =
					((uint16)b & 0x01) |
					((uint16)(b & 0x02) << 1) |
					((uint16)(b & 0x04) << 2) |
					((uint16)(b & 0x08) << 3) |
					((uint16)(b & 0x10) << 4) |
					((uint16)(b & 0x20) << 5) |
					((uint16)(b & 0x40) << 6) |
					((uint16)(b & 0x80) << 7);
			}
			curSignalData.Encode(tick, &dataBuffer);
		}

		void RecordSignal(uint8 data)
		{
			if (curSignalData == null)
				return;

			if (curSignalData.mNumBits == 1)
			{
				uint32 data32 = data;
				curSignalData.Encode(tick, &data32);
				return;
			}

#unwarn
			RecordSignal((.)&data, 1);
		}

		void RecordSignal(uint16 data)
		{
			if (curSignalData == null)
				return;
#unwarn
			RecordSignal((.)&data, 2);
		}

		void RecordSignal(uint32 data)
		{
			if (curSignalData == null)
				return;
#unwarn
			RecordSignal((.)&data, 4);
		}

		void RecordSignal(uint64 data)
		{
			if (curSignalData == null)
				return;
#unwarn
			RecordSignal((.)&data, 8);
		}

		while (ptr < endPtr)
		{
			SigCmd cmd = Read<SigCmd>();
			if (cmd != .DeclareSignal)
			{
				NOP!();
			}

			switch (cmd)
			{
			case .DeclareSignal:
				var sigFlags = Read<SigFlags>();
				var sigCode = Read<uint32>();
				if (sigCode > 1024*1024)
					return .Err;

				Signal signal = new Signal();
				String sigName = Read(.. scope .());
				String sigKind = Read(.. scope .());
				int32 lsb = Read<int32>();
				int32 msb = Read<int32>();
				signal.mNumBits = msb - lsb + 1;
				if (msb > 0)
					signal.mDims = new .()..AppendF($"[{msb}:{lsb}]");

				while (sigCode >= signalDataMap.Count)
					signalDataMap.Add(null);
				if (signalDataMap[sigCode] == null)
				{
					signalDataMap[sigCode] = new .(signal.mNumBits);
					signalDataMap[sigCode].mFirstRef = signal;
				}
				else
					signalDataMap[sigCode].AddRef();
				signal.mSignalData = signalDataMap[sigCode];

				SignalGroup group = topGroup;
				for (var namePart in sigName.Split(' '))
				{
					if (@namePart.HasMore)
					{
						if (group.mGroupMap == null)
						{
							group.mNestedGroups = new .();
							group.mGroupMap = new .();
						}
						if (group.mGroupMap.TryAddAlt(namePart, var keyPtr, var valuePtr))
						{
							var newGroup = new SignalGroup();
							newGroup.mGroup = group;
							newGroup.mName.Set(namePart);
							group.mNestedGroups.Add(newGroup);

							*keyPtr = newGroup.mName;
							*valuePtr = newGroup;
						}
						group = *valuePtr;
					}
					else
					{
						signal.mGroup = group;
						signal.mName = new .(namePart);
						group.mSignals.Add(signal);
						group.mSignalMap[signal.mName] = signal;
						group.mSortDirty = true;
					}
				}
			case .TimeDelta8:
				AddTick(Read<uint8>());
			case .TimeDelta16:
				AddTick(Read<uint16>());
			case .TimeDelta32:
				AddTick(Read<uint32>());
			case .TimeDelta64:
				AddTick(Read<int64>());
			case .Code8:
				SelectSignal(Read<uint8>());
			case .Code16:
				SelectSignal(Read<uint16>());
			case .Code32:
				SelectSignal(Read<uint32>());
			case .Code64:
				SelectSignal((.)Read<int64>());
			case .ValZero:
				RecordSignal((uint8)0);
			case .ValOne:
				RecordSignal((uint8)1);
			case .ValNegOne:
				RecordSignal(0xFFFFFFFFFFFFFFFF);
			case .Val8:
				RecordSignal(Read<uint8>());
			case .Val16:
				RecordSignal(Read<uint16>());
			case .Val32:
				RecordSignal(Read<uint32>());
			case .Val64:
				RecordSignal(Read<uint64>());
			case .ValX:
				int32 dataSize = Read<int32>();
				if (!CheckRead(dataSize))
					return .Err;
				RecordSignal((.)ptr, dataSize);
				ptr += dataSize;
			case .CodeValZero8:
				SelectSignal(Read<uint8>());
				RecordSignal(0);
			case .CodeValZero16:
				SelectSignal(Read<uint16>());
				RecordSignal(0);
			case .CodeValZero32:
				SelectSignal(Read<uint32>());
				RecordSignal(0);
			case .CodeValZero64:
				SelectSignal((.)Read<uint64>());
			case .CodeValOne8:
				SelectSignal(Read<uint8>());
				RecordSignal(1);
			case .CodeValOne16:
				SelectSignal(Read<uint16>());
				RecordSignal(1);
			case .CodeValOne32:
				SelectSignal(Read<uint32>());
				RecordSignal(1);
			case .CodeValOne64:
				SelectSignal((.)Read<uint64>());
				RecordSignal(1);
			case .CodeSetString:
				int32 strIdx = Read<int32>();
				String str = Read(.. scope .());
				if (curSignalData != null)
				{
					if (curSignalData.mStrings == null)
						curSignalData.mStrings = new .();
					if ((strIdx < 0) || (strIdx > 10000000)) // Sanity
						return .Err;
					while (strIdx >= curSignalData.mStrings.Count)
						curSignalData.mStrings.Add(null);
					String.NewOrSet!(curSignalData.mStrings[strIdx], str);
				}
			default:
				return .Err;
			}
		}

		mSigData.mEndTick = tick;
		mSigData.mRoot.Finish();
		return .Ok;
	}
}
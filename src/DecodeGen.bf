using System;
using System.Diagnostics;

namespace SigBuddy;

class DecodeGen
{
	public static void GenerateEncode()
	{
		int curSigBits = 0;

		void GenerateEncoder(int numBytes, int cmdVal, int lenBits, int dataBits)
		{
			int curLenBits = 0;
			int curDataBits = 0;

			if (numBytes > 1)
				Debug.WriteLine($"\t\tuint8* ptr = chunk.mBuffer.GrowUnitialized({numBytes});");

			for (int byteNum < numBytes)
			{
				if (numBytes > 1)
					Debug.Write($"\t\tptr[{byteNum}] = ");
				else
					Debug.Write("\t\tchunk.mBuffer.Add(");
				if (byteNum == 0)
					Debug.Write($"{cmdVal} | ");

				int maxLenBits = (byteNum == 0) ? 6 : 8;

				int useLenBits = Math.Min(lenBits - curLenBits, maxLenBits);
				if (useLenBits > 0)
				{
					Debug.Write($"(uint8)((tickDelta >> {curLenBits}) << {(byteNum == 0) ? 2 : 0})");
				}

				curLenBits += useLenBits;

				int useDataBits = Math.Clamp(dataBits - curDataBits, 0, maxLenBits - useLenBits);
				if (useDataBits > 0)
				{
					if (useLenBits > 0)
						Debug.Write(" | ");

					int useDataBits0 = useDataBits;
					if (useDataBits0 + (curDataBits % 32) > 32)
					{
						useDataBits0 = 32 - (curDataBits % 32);
					}

					Debug.Write($"(uint8)((data[{curDataBits / 32}] >> {curDataBits % 32}) << {useLenBits + ((byteNum == 0) ? 2 : 0)})");


					int useDataBits1 = useDataBits - useDataBits0;
					if (useDataBits1 > 0)
					{
						Runtime.FatalError("Not handled");
						//Debug.Write($" | (uint8)((data[{(curDataBits + useDataBits0) / 32}] >> {(curDataBits + useDataBits0) % 32}) << {useLenBits + useDataBits0 + ((byteNum == 0) ? 2 : 0)})");
					}

					
				}

				curDataBits += useDataBits;

				if (numBytes == 1)
					Debug.Write(")");
				Debug.WriteLine(";");
			}
		}

		void Generate(int sigBits)
		{
			Debug.Write("case ");

			bool isFirst = true;
			while (sigBits > curSigBits)
			{
				if (!isFirst)
					Debug.Write(", ");
				Debug.Write($"{curSigBits + 1}");
				curSigBits++;
				isFirst = false;
			}

			Debug.Write(":\n");

			int lgNumBytes = ((2 + (sigBits * 2) + 24) + 7) / 8;
			int lgLenBits = (lgNumBytes * 8) - 2 - (sigBits * 2);

			int medNumBytes = ((2 + (sigBits * 2) + 12) + 7) / 8;
			int medLenBits = (medNumBytes * 8) - 2 - (sigBits * 2);

			int smNumBytes = ((2 + (sigBits * 2) + 4) + 7) / 8;
			int smLenBits = (smNumBytes * 8) - 2 - (sigBits * 2);

			Debug.Write($$"""
					if (tickDelta < 1<<{{smLenBits}})
					{

				""");
			GenerateEncoder(smNumBytes, 0, smLenBits, sigBits * 2);
			Debug.Write($$"""
					}
					else if (tickDelta < 1<<{{medLenBits}})
					{

				""");
			GenerateEncoder(medNumBytes, 1, medLenBits, sigBits * 2);
			Debug.Write($$"""
					}
					else
					{
						if (tickDelta >= 1<<{{lgLenBits}})
						{
							Encode(chunk.mEndTick + (1<<{{lgLenBits}}) - 1, data);
							Encode(tick, data);
							return;
						}
		
				""");
			GenerateEncoder(lgNumBytes, 2, lgLenBits, sigBits * 2);
			Debug.Write("""
					}

				""");
		}

		for (var size in mSizes)
			Generate(size);
	}

	static int[] mSizes = new .[] (1, 2, 3, 4, 6, 8, 12, 16, 24, 32, 40, 64);

	public static void GenerateDecode()
	{
		Debug.WriteLine("");
		Debug.WriteLine("/////////////////////////////////////////////////////////////////////");
		Debug.WriteLine("");

		int curSigBits = 0;

		void GenerateDecoder(int numBytes, int lenBits, int dataBits)
		{
			int curLenBits = 0;
			int curDataBits = 0;
			int curDataByte = -1;

			Debug.Write($"\t\ttickDelta = ");

			for (int byteNum < numBytes)
			{
				int maxLenBits = (byteNum == 0) ? 6 : 8;

				int useLenBits = Math.Min(lenBits - curLenBits, maxLenBits);
				if (useLenBits > 0)
				{
					if (byteNum > 0)
						Debug.Write(" |\n\t\t\t");
					//Debug.Write($"(uint8)((tickDelta >> {curLenBits}) << {(byteNum == 0) ? 2 : 0})");
					Debug.Write($"((int64)((ptr[{byteNum}]");
					if (byteNum == 0)
						Debug.Write($" >> 2");
					Debug.Write(")");
					if (useLenBits != 8)
						Debug.Write($" & 0x{((1<<useLenBits)-1):X}");
					Debug.Write(")");
					if (curLenBits > 0)
						Debug.Write($" << {curLenBits}");
					Debug.Write(")");
				}

				curLenBits += useLenBits;

				void CheckStartByte(int dataByte)
				{
					if (dataByte == curDataByte)
					{
						Debug.Write(" |\n\t\t\t");
						return;
					}

					Debug.WriteLine(";");

					curDataByte = dataByte;
					Debug.Write($"\t\tdata[{curDataByte}] = ");
				}

				int useDataBits = Math.Clamp(dataBits - curDataBits, 0, maxLenBits - useLenBits);
				if (useDataBits > 0)
				{
					CheckStartByte(curDataBits / 32);

					int useDataBits0 = useDataBits;
					if (useDataBits0 + (curDataBits % 32) > 32)
					{
						useDataBits0 = 32 - (curDataBits % 32);
					}

					int dataShift = useLenBits + ((byteNum == 0) ? 2 : 0);

					Debug.Write($"((uint32)((ptr[{byteNum}]");
					if (dataShift != 0)
						Debug.Write($" >> {dataShift}");
					Debug.Write(")");
					if ((curDataBits % 32) > 0)
						Debug.Write($") << {curDataBits % 32}");
					else
						Debug.Write(")");
					Debug.Write(")");

					int useDataBits1 = useDataBits - useDataBits0;
					if (useDataBits1 > 0)
					{
					
					}
				}

				curDataBits += useDataBits;
			}
			Debug.WriteLine(";");
			Debug.WriteLine($"\t\tptr += {numBytes};");
		}

		void Generate(int sigBits)
		{
			Debug.Write("case ");

			bool isFirst = true;
			while (sigBits > curSigBits)
			{
				if (!isFirst)
					Debug.Write(", ");
				Debug.Write($"{curSigBits + 1}");
				curSigBits++;
				isFirst = false;
			}

			Debug.Write(":\n");

			int lgNumBytes = ((2 + (sigBits * 2) + 24) + 7) / 8;
			int lgLenBits = (lgNumBytes * 8) - 2 - (sigBits * 2);

			int medNumBytes = ((2 + (sigBits * 2) + 12) + 7) / 8;
			int medLenBits = (medNumBytes * 8) - 2 - (sigBits * 2);

			int smNumBytes = ((2 + (sigBits * 2) + 4) + 7) / 8;
			int smLenBits = (smNumBytes * 8) - 2 - (sigBits * 2);



			Debug.Write("""
					if ((*ptr & 3) == 0)
					{

				""");
			GenerateDecoder(smNumBytes, smLenBits, sigBits * 2);
			Debug.Write("""
					}
					else if ((*ptr & 3) == 1)
					{

				""");
			GenerateDecoder(medNumBytes, medLenBits, sigBits * 2);
			Debug.Write("""
					}
					else
					{
		
				""");
			GenerateDecoder(lgNumBytes, lgLenBits, sigBits * 2);
			Debug.Write("""
					}

				""");
		}

		for (var size in mSizes)
			Generate(size);
	}

	public static void TestSignalEncoding()
	{
		Random rand = scope .(8);

		for (int32 numBits in 1...200)
		{
			for (int i < 10000)
			{
				uint32* bitsIn = scope uint32[100]* ( ? );
				uint32* bitsOut = scope uint32[100]* ( ? );

				SignalData signal = new .();
				signal.mNumBits = numBits;

				for (int dataIdx < (numBits + 31) / 32)
				{
					bitsIn[dataIdx] = rand.NextU32();

					int maxBits = numBits - (dataIdx * 32);
					if ((maxBits >= 0) && (maxBits < 32))
						bitsIn[dataIdx] &= (1<<maxBits)-1;
				}

				int deltaBits = rand.NextI32() % 32;
				int64 ticksDelta = rand.NextI32() & ((1<<deltaBits) - 1);

				if (numBits == 161)
				{
					if (i == 0)
					{
						NOP!();
					}
				}

				signal.Encode(0, bitsIn);
				signal.Encode(ticksDelta, bitsIn);

				var chunk = signal.mChunks.Front;

				uint8* ptr = chunk.mBuffer.Ptr;
				signal.Decode(ref ptr, bitsOut, var outTicksDelta);
				Runtime.Assert(outTicksDelta == 0);
				for (int dataIdx < (numBits + 31) / 32)
					Runtime.Assert(bitsIn[dataIdx] == bitsOut[dataIdx]);

				signal.Decode(ref ptr, bitsOut, out outTicksDelta);
				for (int dataIdx < (numBits + 31) / 32)
					Runtime.Assert(bitsIn[dataIdx] == bitsOut[dataIdx]);

				int64 curOutTick = outTicksDelta;

				while (curOutTick != ticksDelta)
				{
					Runtime.Assert(ptr <= &chunk.mBuffer.Back);

					signal.Decode(ref ptr, bitsOut, out outTicksDelta);
					for (int dataIdx < (numBits + 31) / 32)
						Runtime.Assert(bitsIn[dataIdx] == bitsOut[dataIdx]);

					curOutTick += outTicksDelta;
				}
				
				//Runtime.Assert(ticksDelta == outTicksDelta);

				signal.ReleaseLastRef();
			}
		}

	}
}
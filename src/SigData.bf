using System;
using System.IO;
using System.Diagnostics;
using System.Collections;

namespace SigBuddy;


// 1 bit signal
// Sm: 2 bit cmd, 5 bit skip, 1 bit value = 8 bit
// Med: 2 bit cmd, 13 bit skip, 1 bit value = 16 bit
// Lg: 2 bit cmd, 29 bit skip, 1 bit value = 32 bit

// 2 bit signal
// Sm: 2 bit cmd, 4 bit skip, 2 bit value = 8 bit
// Med: 2 bit cmd, 12 bit skip, 2 bit value = 16 bit
// Lg: 2 bit cmd, 28 bit skip, 2 bit value = 32 bit

// 5 bit signal
// Sm: 2 bit cmd, 9 bit skip, 5 bit value = 16 bit
// Med: 2 bit cmd, 16 bit skip, 5 bit value = 24 bit
// Lg: 2 bit cmd, 25 bit skip, 2 bit value = 32 bit

enum SigCmd
{
	DeltaSm, // IE: 2 bit cmd, 5 bit skip, 1 bit value
	DeltaMd, // IE: 2 bit cmd, 13 bit skip, 1 bit value
	DeltaLg,
	End
}

public class SignalChunkData
{
	public const int cDataSize = 32*1024;

	public List<uint8> mBuffer ~ delete _;

	public int32 mNumBits;
	public int64 mStartTick = -1;
	public int64 mEndTick = -1;
	public int64 mMinDelta = int64.MaxValue / 2;

	public int64 mDeltaEncodeOffset;
	public int64 mDeltaShift;

	public this(int initDataSize = cDataSize)
	{
		mBuffer = new .(initDataSize);
	}

	public void Finish()
	{
	}

	public void Encode(int64 tickDelta, uint32* data)
	{
		if (tickDelta < mMinDelta)
		{
			if (!mBuffer.IsEmpty)
				mMinDelta = tickDelta;
		}

		switch (mNumBits)
		{
		case 1:
			if (tickDelta < 1 << 4)
			{
				mBuffer.Add(0 | (uint8)((tickDelta >> 0) << 2) | (uint8)((data[0] >> 0) << 6));
				return;
			}
			else if (tickDelta < 1 << 12)
			{
				uint8* ptr = mBuffer.GrowUnitialized(2);
				ptr[0] = 1 | (uint8)((tickDelta >> 0) << 2);
				ptr[1] = (uint8)((tickDelta >> 6) << 0) | (uint8)((data[0] >> 0) << 6);
				return;
			}
			else if (tickDelta < 1 << 28)
			{
				uint8* ptr = mBuffer.GrowUnitialized(4);
				*(uint32*)ptr = 2 | ((uint32)tickDelta << 2) | (data[0] << 30);
				return;
			}
		case 2:
			if (tickDelta < 1 << 10)
			{
				uint8* ptr = mBuffer.GrowUnitialized(2);
				ptr[0] = 0 | (uint8)((tickDelta >> 0) << 2);
				ptr[1] = (uint8)((tickDelta >> 6) << 0) | (uint8)((data[0] >> 0) << 4);
				return;
			}
			else if (tickDelta < 1 << 18)
			{
				uint8* ptr = mBuffer.GrowUnitialized(3);
				ptr[0] = 1 | (uint8)((tickDelta >> 0) << 2);
				ptr[1] = (uint8)((tickDelta >> 6) << 0);
				ptr[2] = (uint8)((tickDelta >> 14) << 0) | (uint8)((data[0] >> 0) << 4);
				return;
			}
			else if (tickDelta < 1 << 26)
			{
				uint8* ptr = mBuffer.GrowUnitialized(4);
				ptr[0] = 2 | (uint8)((tickDelta >> 0) << 2);
				ptr[1] = (uint8)((tickDelta >> 6) << 0);
				ptr[2] = (uint8)((tickDelta >> 14) << 0);
				ptr[3] = (uint8)((tickDelta >> 22) << 0) | (uint8)((data[0] >> 0) << 4);
				return;
			}
		case 3:
			if (tickDelta < 1 << 8)
			{
				uint8* ptr = mBuffer.GrowUnitialized(2);
				ptr[0] = 0 | (uint8)((tickDelta >> 0) << 2);
				ptr[1] = (uint8)((tickDelta >> 6) << 0) | (uint8)((data[0] >> 0) << 2);
				return;
			}
			else if (tickDelta < 1 << 16)
			{
				uint8* ptr = mBuffer.GrowUnitialized(3);
				ptr[0] = 1 | (uint8)((tickDelta >> 0) << 2);
				ptr[1] = (uint8)((tickDelta >> 6) << 0);
				ptr[2] = (uint8)((tickDelta >> 14) << 0) | (uint8)((data[0] >> 0) << 2);
				return;
			}
			else if (tickDelta < 1 << 24)
			{
				uint8* ptr = mBuffer.GrowUnitialized(4);
				ptr[0] = 2 | (uint8)((tickDelta >> 0) << 2);
				ptr[1] = (uint8)((tickDelta >> 6) << 0);
				ptr[2] = (uint8)((tickDelta >> 14) << 0);
				ptr[3] = (uint8)((tickDelta >> 22) << 0) | (uint8)((data[0] >> 0) << 2);
				return;
			}
		case 4:
			if (tickDelta < 1 << 6)
			{
				uint8* ptr = mBuffer.GrowUnitialized(2);
				ptr[0] = 0 | (uint8)((tickDelta >> 0) << 2);
				ptr[1] = (uint8)((data[0] >> 0) << 0);
				return;
			}
			else if (tickDelta < 1 << 14)
			{
				uint8* ptr = mBuffer.GrowUnitialized(3);
				ptr[0] = 1 | (uint8)((tickDelta >> 0) << 2);
				ptr[1] = (uint8)((tickDelta >> 6) << 0);
				ptr[2] = (uint8)((data[0] >> 0) << 0);
				return;
			}
			else if (tickDelta < 1 << 30)
			{
				uint8* ptr = mBuffer.GrowUnitialized(5);
				ptr[0] = 2 | (uint8)((tickDelta >> 0) << 2);
				ptr[1] = (uint8)((tickDelta >> 6) << 0);
				ptr[2] = (uint8)((tickDelta >> 14) << 0);
				ptr[3] = (uint8)((tickDelta >> 22) << 0);
				ptr[4] = (uint8)((data[0] >> 0) << 0);
				return;
			}
		case 5,6:
			if (tickDelta < 1 << 10)
			{
				uint8* ptr = mBuffer.GrowUnitialized(3);
				ptr[0] = 0 | (uint8)((tickDelta >> 0) << 2);
				ptr[1] = (uint8)((tickDelta >> 6) << 0) | (uint8)((data[0] >> 0) << 4);
				ptr[2] = (uint8)((data[0] >> 4) << 0);
				return;
			}
			else if (tickDelta < 1 << 18)
			{
				uint8* ptr = mBuffer.GrowUnitialized(4);
				ptr[0] = 1 | (uint8)((tickDelta >> 0) << 2);
				ptr[1] = (uint8)((tickDelta >> 6) << 0);
				ptr[2] = (uint8)((tickDelta >> 14) << 0) | (uint8)((data[0] >> 0) << 4);
				ptr[3] = (uint8)((data[0] >> 4) << 0);
				return;
			}
			else if (tickDelta < 1 << 26)
			{
				uint8* ptr = mBuffer.GrowUnitialized(5);
				ptr[0] = 2 | (uint8)((tickDelta >> 0) << 2);
				ptr[1] = (uint8)((tickDelta >> 6) << 0);
				ptr[2] = (uint8)((tickDelta >> 14) << 0);
				ptr[3] = (uint8)((tickDelta >> 22) << 0) | (uint8)((data[0] >> 0) << 4);
				ptr[4] = (uint8)((data[0] >> 4) << 0);
				return;
			}
		case 7,8:
			if (tickDelta < 1 << 6)
			{
				uint8* ptr = mBuffer.GrowUnitialized(3);
				ptr[0] = 0 | (uint8)((tickDelta >> 0) << 2);
				ptr[1] = (uint8)((data[0] >> 0) << 0);
				ptr[2] = (uint8)((data[0] >> 8) << 0);
				return;
			}
			else if (tickDelta < 1 << 14)
			{
				uint8* ptr = mBuffer.GrowUnitialized(4);
				ptr[0] = 1 | (uint8)((tickDelta >> 0) << 2);
				ptr[1] = (uint8)((tickDelta >> 6) << 0);
				ptr[2] = (uint8)((data[0] >> 0) << 0);
				ptr[3] = (uint8)((data[0] >> 8) << 0);
				return;
			}
			else if (tickDelta < 1 << 30)
			{
				uint8* ptr = mBuffer.GrowUnitialized(6);
				ptr[0] = 2 | (uint8)((tickDelta >> 0) << 2);
				ptr[1] = (uint8)((tickDelta >> 6) << 0);
				ptr[2] = (uint8)((tickDelta >> 14) << 0);
				ptr[3] = (uint8)((tickDelta >> 22) << 0);
				ptr[4] = (uint8)((data[0] >> 0) << 0);
				ptr[5] = (uint8)((data[0] >> 8) << 0);
				return;
			}
		case 9,10,11,12:
			if (tickDelta < 1 << 6)
			{
				uint8* ptr = mBuffer.GrowUnitialized(4);
				ptr[0] = 0 | (uint8)((tickDelta >> 0) << 2);
				ptr[1] = (uint8)((data[0] >> 0) << 0);
				ptr[2] = (uint8)((data[0] >> 8) << 0);
				ptr[3] = (uint8)((data[0] >> 16) << 0);
				return;
			}
			else if (tickDelta < 1 << 14)
			{
				uint8* ptr = mBuffer.GrowUnitialized(5);
				ptr[0] = 1 | (uint8)((tickDelta >> 0) << 2);
				ptr[1] = (uint8)((tickDelta >> 6) << 0);
				ptr[2] = (uint8)((data[0] >> 0) << 0);
				ptr[3] = (uint8)((data[0] >> 8) << 0);
				ptr[4] = (uint8)((data[0] >> 16) << 0);
				return;
			}
			else if (tickDelta < 1 << 30)
			{
				uint8* ptr = mBuffer.GrowUnitialized(7);
				ptr[0] = 2 | (uint8)((tickDelta >> 0) << 2);
				ptr[1] = (uint8)((tickDelta >> 6) << 0);
				ptr[2] = (uint8)((tickDelta >> 14) << 0);
				ptr[3] = (uint8)((tickDelta >> 22) << 0);
				ptr[4] = (uint8)((data[0] >> 0) << 0);
				ptr[5] = (uint8)((data[0] >> 8) << 0);
				ptr[6] = (uint8)((data[0] >> 16) << 0);
				return;
			}
		case 13,14,15,16:
			if (tickDelta < 1 << 6)
			{
				uint8* ptr = mBuffer.GrowUnitialized(5);
				ptr[0] = 0 | (uint8)((tickDelta >> 0) << 2);
				ptr[1] = (uint8)((data[0] >> 0) << 0);
				ptr[2] = (uint8)((data[0] >> 8) << 0);
				ptr[3] = (uint8)((data[0] >> 16) << 0);
				ptr[4] = (uint8)((data[0] >> 24) << 0);
				return;
			}
			else if (tickDelta < 1 << 14)
			{
				uint8* ptr = mBuffer.GrowUnitialized(6);
				ptr[0] = 1 | (uint8)((tickDelta >> 0) << 2);
				ptr[1] = (uint8)((tickDelta >> 6) << 0);
				ptr[2] = (uint8)((data[0] >> 0) << 0);
				ptr[3] = (uint8)((data[0] >> 8) << 0);
				ptr[4] = (uint8)((data[0] >> 16) << 0);
				ptr[5] = (uint8)((data[0] >> 24) << 0);
				return;
			}
			else if (tickDelta < 1 << 30)
			{
				uint8* ptr = mBuffer.GrowUnitialized(8);
				ptr[0] = 2 | (uint8)((tickDelta >> 0) << 2);
				ptr[1] = (uint8)((tickDelta >> 6) << 0);
				ptr[2] = (uint8)((tickDelta >> 14) << 0);
				ptr[3] = (uint8)((tickDelta >> 22) << 0);
				ptr[4] = (uint8)((data[0] >> 0) << 0);
				ptr[5] = (uint8)((data[0] >> 8) << 0);
				ptr[6] = (uint8)((data[0] >> 16) << 0);
				ptr[7] = (uint8)((data[0] >> 24) << 0);
				return;
			}
		case 17,18,19,20,21,22,23,24:
			if (tickDelta < 1 << 6)
			{
				uint8* ptr = mBuffer.GrowUnitialized(7);
				ptr[0] = 0 | (uint8)((tickDelta >> 0) << 2);
				ptr[1] = (uint8)((data[0] >> 0) << 0);
				ptr[2] = (uint8)((data[0] >> 8) << 0);
				ptr[3] = (uint8)((data[0] >> 16) << 0);
				ptr[4] = (uint8)((data[0] >> 24) << 0);
				ptr[5] = (uint8)((data[1] >> 0) << 0);
				ptr[6] = (uint8)((data[1] >> 8) << 0);
				return;
			}
			else if (tickDelta < 1 << 14)
			{
				uint8* ptr = mBuffer.GrowUnitialized(8);
				ptr[0] = 1 | (uint8)((tickDelta >> 0) << 2);
				ptr[1] = (uint8)((tickDelta >> 6) << 0);
				ptr[2] = (uint8)((data[0] >> 0) << 0);
				ptr[3] = (uint8)((data[0] >> 8) << 0);
				ptr[4] = (uint8)((data[0] >> 16) << 0);
				ptr[5] = (uint8)((data[0] >> 24) << 0);
				ptr[6] = (uint8)((data[1] >> 0) << 0);
				ptr[7] = (uint8)((data[1] >> 8) << 0);
				return;
			}
			else if (tickDelta < 1 << 30)
			{
				uint8* ptr = mBuffer.GrowUnitialized(10);
				ptr[0] = 2 | (uint8)((tickDelta >> 0) << 2);
				ptr[1] = (uint8)((tickDelta >> 6) << 0);
				ptr[2] = (uint8)((tickDelta >> 14) << 0);
				ptr[3] = (uint8)((tickDelta >> 22) << 0);
				ptr[4] = (uint8)((data[0] >> 0) << 0);
				ptr[5] = (uint8)((data[0] >> 8) << 0);
				ptr[6] = (uint8)((data[0] >> 16) << 0);
				ptr[7] = (uint8)((data[0] >> 24) << 0);
				ptr[8] = (uint8)((data[1] >> 0) << 0);
				ptr[9] = (uint8)((data[1] >> 8) << 0);
				return;
			}
		case 25,26,27,28,29,30,31,32:
			if (tickDelta < 1 << 6)
			{
				uint8* ptr = mBuffer.GrowUnitialized(9);
				ptr[0] = 0 | (uint8)((tickDelta >> 0) << 2);
				ptr[1] = (uint8)((data[0] >> 0) << 0);
				ptr[2] = (uint8)((data[0] >> 8) << 0);
				ptr[3] = (uint8)((data[0] >> 16) << 0);
				ptr[4] = (uint8)((data[0] >> 24) << 0);
				ptr[5] = (uint8)((data[1] >> 0) << 0);
				ptr[6] = (uint8)((data[1] >> 8) << 0);
				ptr[7] = (uint8)((data[1] >> 16) << 0);
				ptr[8] = (uint8)((data[1] >> 24) << 0);
				return;
			}
			else if (tickDelta < 1 << 14)
			{
				uint8* ptr = mBuffer.GrowUnitialized(10);
				ptr[0] = 1 | (uint8)((tickDelta >> 0) << 2);
				ptr[1] = (uint8)((tickDelta >> 6) << 0);
				ptr[2] = (uint8)((data[0] >> 0) << 0);
				ptr[3] = (uint8)((data[0] >> 8) << 0);
				ptr[4] = (uint8)((data[0] >> 16) << 0);
				ptr[5] = (uint8)((data[0] >> 24) << 0);
				ptr[6] = (uint8)((data[1] >> 0) << 0);
				ptr[7] = (uint8)((data[1] >> 8) << 0);
				ptr[8] = (uint8)((data[1] >> 16) << 0);
				ptr[9] = (uint8)((data[1] >> 24) << 0);
				return;
			}
			else if (tickDelta < 1 << 30)
			{
				uint8* ptr = mBuffer.GrowUnitialized(12);
				ptr[0] = 2 | (uint8)((tickDelta >> 0) << 2);
				ptr[1] = (uint8)((tickDelta >> 6) << 0);
				ptr[2] = (uint8)((tickDelta >> 14) << 0);
				ptr[3] = (uint8)((tickDelta >> 22) << 0);
				ptr[4] = (uint8)((data[0] >> 0) << 0);
				ptr[5] = (uint8)((data[0] >> 8) << 0);
				ptr[6] = (uint8)((data[0] >> 16) << 0);
				ptr[7] = (uint8)((data[0] >> 24) << 0);
				ptr[8] = (uint8)((data[1] >> 0) << 0);
				ptr[9] = (uint8)((data[1] >> 8) << 0);
				ptr[10] = (uint8)((data[1] >> 16) << 0);
				ptr[11] = (uint8)((data[1] >> 24) << 0);
				return;
			}
		case 33,34,35,36,37,38,39,40:
			if (tickDelta < 1 << 6)
			{
				uint8* ptr = mBuffer.GrowUnitialized(11);
				ptr[0] = 0 | (uint8)((tickDelta >> 0) << 2);
				ptr[1] = (uint8)((data[0] >> 0) << 0);
				ptr[2] = (uint8)((data[0] >> 8) << 0);
				ptr[3] = (uint8)((data[0] >> 16) << 0);
				ptr[4] = (uint8)((data[0] >> 24) << 0);
				ptr[5] = (uint8)((data[1] >> 0) << 0);
				ptr[6] = (uint8)((data[1] >> 8) << 0);
				ptr[7] = (uint8)((data[1] >> 16) << 0);
				ptr[8] = (uint8)((data[1] >> 24) << 0);
				ptr[9] = (uint8)((data[2] >> 0) << 0);
				ptr[10] = (uint8)((data[2] >> 8) << 0);
				return;
			}
			else if (tickDelta < 1 << 14)
			{
				uint8* ptr = mBuffer.GrowUnitialized(12);
				ptr[0] = 1 | (uint8)((tickDelta >> 0) << 2);
				ptr[1] = (uint8)((tickDelta >> 6) << 0);
				ptr[2] = (uint8)((data[0] >> 0) << 0);
				ptr[3] = (uint8)((data[0] >> 8) << 0);
				ptr[4] = (uint8)((data[0] >> 16) << 0);
				ptr[5] = (uint8)((data[0] >> 24) << 0);
				ptr[6] = (uint8)((data[1] >> 0) << 0);
				ptr[7] = (uint8)((data[1] >> 8) << 0);
				ptr[8] = (uint8)((data[1] >> 16) << 0);
				ptr[9] = (uint8)((data[1] >> 24) << 0);
				ptr[10] = (uint8)((data[2] >> 0) << 0);
				ptr[11] = (uint8)((data[2] >> 8) << 0);
				return;
			}
			else if (tickDelta < 1 << 30)
			{
				uint8* ptr = mBuffer.GrowUnitialized(14);
				ptr[0] = 2 | (uint8)((tickDelta >> 0) << 2);
				ptr[1] = (uint8)((tickDelta >> 6) << 0);
				ptr[2] = (uint8)((tickDelta >> 14) << 0);
				ptr[3] = (uint8)((tickDelta >> 22) << 0);
				ptr[4] = (uint8)((data[0] >> 0) << 0);
				ptr[5] = (uint8)((data[0] >> 8) << 0);
				ptr[6] = (uint8)((data[0] >> 16) << 0);
				ptr[7] = (uint8)((data[0] >> 24) << 0);
				ptr[8] = (uint8)((data[1] >> 0) << 0);
				ptr[9] = (uint8)((data[1] >> 8) << 0);
				ptr[10] = (uint8)((data[1] >> 16) << 0);
				ptr[11] = (uint8)((data[1] >> 24) << 0);
				ptr[12] = (uint8)((data[2] >> 0) << 0);
				ptr[13] = (uint8)((data[2] >> 8) << 0);
				return;
			}
		case 41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64:
			if (tickDelta < 1 << 6)
			{
				uint8* ptr = mBuffer.GrowUnitialized(17);
				ptr[0] = 0 | (uint8)((tickDelta >> 0) << 2);
				ptr[1] = (uint8)((data[0] >> 0) << 0);
				ptr[2] = (uint8)((data[0] >> 8) << 0);
				ptr[3] = (uint8)((data[0] >> 16) << 0);
				ptr[4] = (uint8)((data[0] >> 24) << 0);
				ptr[5] = (uint8)((data[1] >> 0) << 0);
				ptr[6] = (uint8)((data[1] >> 8) << 0);
				ptr[7] = (uint8)((data[1] >> 16) << 0);
				ptr[8] = (uint8)((data[1] >> 24) << 0);
				ptr[9] = (uint8)((data[2] >> 0) << 0);
				ptr[10] = (uint8)((data[2] >> 8) << 0);
				ptr[11] = (uint8)((data[2] >> 16) << 0);
				ptr[12] = (uint8)((data[2] >> 24) << 0);
				ptr[13] = (uint8)((data[3] >> 0) << 0);
				ptr[14] = (uint8)((data[3] >> 8) << 0);
				ptr[15] = (uint8)((data[3] >> 16) << 0);
				ptr[16] = (uint8)((data[3] >> 24) << 0);
				return;
			}
			else if (tickDelta < 1 << 14)
			{
				uint8* ptr = mBuffer.GrowUnitialized(18);
				ptr[0] = 1 | (uint8)((tickDelta >> 0) << 2);
				ptr[1] = (uint8)((tickDelta >> 6) << 0);
				ptr[2] = (uint8)((data[0] >> 0) << 0);
				ptr[3] = (uint8)((data[0] >> 8) << 0);
				ptr[4] = (uint8)((data[0] >> 16) << 0);
				ptr[5] = (uint8)((data[0] >> 24) << 0);
				ptr[6] = (uint8)((data[1] >> 0) << 0);
				ptr[7] = (uint8)((data[1] >> 8) << 0);
				ptr[8] = (uint8)((data[1] >> 16) << 0);
				ptr[9] = (uint8)((data[1] >> 24) << 0);
				ptr[10] = (uint8)((data[2] >> 0) << 0);
				ptr[11] = (uint8)((data[2] >> 8) << 0);
				ptr[12] = (uint8)((data[2] >> 16) << 0);
				ptr[13] = (uint8)((data[2] >> 24) << 0);
				ptr[14] = (uint8)((data[3] >> 0) << 0);
				ptr[15] = (uint8)((data[3] >> 8) << 0);
				ptr[16] = (uint8)((data[3] >> 16) << 0);
				ptr[17] = (uint8)((data[3] >> 24) << 0);
				return;
			}
			else if (tickDelta < 1 << 30)
			{
				uint8* ptr = mBuffer.GrowUnitialized(20);
				ptr[0] = 2 | (uint8)((tickDelta >> 0) << 2);
				ptr[1] = (uint8)((tickDelta >> 6) << 0);
				ptr[2] = (uint8)((tickDelta >> 14) << 0);
				ptr[3] = (uint8)((tickDelta >> 22) << 0);
				ptr[4] = (uint8)((data[0] >> 0) << 0);
				ptr[5] = (uint8)((data[0] >> 8) << 0);
				ptr[6] = (uint8)((data[0] >> 16) << 0);
				ptr[7] = (uint8)((data[0] >> 24) << 0);
				ptr[8] = (uint8)((data[1] >> 0) << 0);
				ptr[9] = (uint8)((data[1] >> 8) << 0);
				ptr[10] = (uint8)((data[1] >> 16) << 0);
				ptr[11] = (uint8)((data[1] >> 24) << 0);
				ptr[12] = (uint8)((data[2] >> 0) << 0);
				ptr[13] = (uint8)((data[2] >> 8) << 0);
				ptr[14] = (uint8)((data[2] >> 16) << 0);
				ptr[15] = (uint8)((data[2] >> 24) << 0);
				ptr[16] = (uint8)((data[3] >> 0) << 0);
				ptr[17] = (uint8)((data[3] >> 8) << 0);
				ptr[18] = (uint8)((data[3] >> 16) << 0);
				ptr[19] = (uint8)((data[3] >> 24) << 0);
				return;
			}
		default:
			int32 numBytes = (mNumBits * 2 + 7) / 8;
			if (tickDelta < 1 << 6)
			{
				uint8* ptr = mBuffer.GrowUnitialized(1 + numBytes);
				ptr[0] = 0 | (uint8)((tickDelta >> 0) << 2);
				Internal.MemCpy(ptr + 1, data, numBytes);
				return;
			}
			else if (tickDelta < 1 << 14)
			{
				uint8* ptr = mBuffer.GrowUnitialized(2 + numBytes);
				ptr[0] = 1 | (uint8)((tickDelta >> 0) << 2);
				ptr[1] = (uint8)((tickDelta >> 6) << 0);
				Internal.MemCpy(ptr + 2, data, numBytes);
				return;
			}
			else if (tickDelta < 1 << 30)
			{
				uint8* ptr = mBuffer.GrowUnitialized(4 + numBytes);
				ptr[0] = 2 | (uint8)((tickDelta >> 0) << 2);
				ptr[1] = (uint8)((tickDelta >> 6) << 0);
				ptr[2] = (uint8)((tickDelta >> 14) << 0);
				ptr[3] = (uint8)((tickDelta >> 22) << 0);
				Internal.MemCpy(ptr + 4, data, numBytes);
				return;
			}
		}

		int32 numBytes = (mNumBits * 2 + 7) / 8;
		uint8* ptr = mBuffer.GrowUnitialized(1 + 8 + numBytes);
		ptr[0] = 3 | (1 << 2);
		*(int64*)&ptr[1] = tickDelta;
		Internal.MemCpy(ptr + 1 + 8, data, numBytes);
	}

	public void Decode(ref uint8* ptr, uint32* data, out int64 tickDelta)
	{
		tickDelta = 0;
		switch (mNumBits)
		{
		case 1:
			if ((*ptr & 3) == 0)
			{
				tickDelta = ((int64)((ptr[0] >> 2) & 0xF));
				data[0] = ((uint32)((ptr[0] >> 6)));
				ptr += 1;
				return;
			}
			else if ((*ptr & 3) == 1)
			{
				tickDelta = ((int64)((ptr[0] >> 2) & 0x3F)) |
					((int64)((ptr[1]) & 0x3F) << 6);
				data[0] = ((uint32)((ptr[1] >> 6)));
				ptr += 2;
				return;
			}
			else if ((*ptr & 3) == 2)
			{
				tickDelta = ((int64)((ptr[0] >> 2) & 0x3F)) |
					((int64)((ptr[1])) << 6) |
					((int64)((ptr[2])) << 14) |
					((int64)((ptr[3]) & 0x3F) << 22);
				data[0] = ((uint32)((ptr[3] >> 6)));
				ptr += 4;
				return;
			}
		case 2:
			if ((*ptr & 3) == 0)
			{
				tickDelta = ((int64)((ptr[0] >> 2) & 0x3F)) |
					((int64)((ptr[1]) & 0xF) << 6);
				data[0] = ((uint32)((ptr[1] >> 4)));
				ptr += 2;
				return;
			}
			else if ((*ptr & 3) == 1)
			{
				tickDelta = ((int64)((ptr[0] >> 2) & 0x3F)) |
					((int64)((ptr[1])) << 6) |
					((int64)((ptr[2]) & 0xF) << 14);
				data[0] = ((uint32)((ptr[2] >> 4)));
				ptr += 3;
				return;
			}
			else if ((*ptr & 3) == 2)
			{
				tickDelta = ((int64)((ptr[0] >> 2) & 0x3F)) |
					((int64)((ptr[1])) << 6) |
					((int64)((ptr[2])) << 14) |
					((int64)((ptr[3]) & 0xF) << 22);
				data[0] = ((uint32)((ptr[3] >> 4)));
				ptr += 4;
				return;
			}
		case 3:
			if ((*ptr & 3) == 0)
			{
				tickDelta = ((int64)((ptr[0] >> 2) & 0x3F)) |
					((int64)((ptr[1]) & 0x3) << 6);
				data[0] = ((uint32)((ptr[1] >> 2)));
				ptr += 2;
				return;
			}
			else if ((*ptr & 3) == 1)
			{
				tickDelta = ((int64)((ptr[0] >> 2) & 0x3F)) |
					((int64)((ptr[1])) << 6) |
					((int64)((ptr[2]) & 0x3) << 14);
				data[0] = ((uint32)((ptr[2] >> 2)));
				ptr += 3;
				return;
			}
			else if ((*ptr & 3) == 2)
			{
				tickDelta = ((int64)((ptr[0] >> 2) & 0x3F)) |
					((int64)((ptr[1])) << 6) |
					((int64)((ptr[2])) << 14) |
					((int64)((ptr[3]) & 0x3) << 22);
				data[0] = ((uint32)((ptr[3] >> 2)));
				ptr += 4;
				return;
			}
		case 4:
			if ((*ptr & 3) == 0)
			{
				tickDelta = ((int64)((ptr[0] >> 2) & 0x3F));
				data[0] = ((uint32)((ptr[1])));
				ptr += 2;
				return;
			}
			else if ((*ptr & 3) == 1)
			{
				tickDelta = ((int64)((ptr[0] >> 2) & 0x3F)) |
					((int64)((ptr[1])) << 6);
				data[0] = ((uint32)((ptr[2])));
				ptr += 3;
				return;
			}
			else if ((*ptr & 3) == 2)
			{
				tickDelta = ((int64)((ptr[0] >> 2) & 0x3F)) |
					((int64)((ptr[1])) << 6) |
					((int64)((ptr[2])) << 14) |
					((int64)((ptr[3])) << 22);
				data[0] = ((uint32)((ptr[4])));
				ptr += 5;
				return;
			}
		case 5,6:
			if ((*ptr & 3) == 0)
			{
				tickDelta = ((int64)((ptr[0] >> 2) & 0x3F)) |
					((int64)((ptr[1]) & 0xF) << 6);
				data[0] = ((uint32)((ptr[1] >> 4))) |
					((uint32)((ptr[2])) << 4);
				ptr += 3;
				return;
			}
			else if ((*ptr & 3) == 1)
			{
				tickDelta = ((int64)((ptr[0] >> 2) & 0x3F)) |
					((int64)((ptr[1])) << 6) |
					((int64)((ptr[2]) & 0xF) << 14);
				data[0] = ((uint32)((ptr[2] >> 4))) |
					((uint32)((ptr[3])) << 4);
				ptr += 4;
				return;
			}
			else if ((*ptr & 3) == 2)
			{
				tickDelta = ((int64)((ptr[0] >> 2) & 0x3F)) |
					((int64)((ptr[1])) << 6) |
					((int64)((ptr[2])) << 14) |
					((int64)((ptr[3]) & 0xF) << 22);
				data[0] = ((uint32)((ptr[3] >> 4))) |
					((uint32)((ptr[4])) << 4);
				ptr += 5;
				return;
			}
		case 7,8:
			if ((*ptr & 3) == 0)
			{
				tickDelta = ((int64)((ptr[0] >> 2) & 0x3F));
				data[0] = ((uint32)((ptr[1]))) |
					((uint32)((ptr[2])) << 8);
				ptr += 3;
				return;
			}
			else if ((*ptr & 3) == 1)
			{
				tickDelta = ((int64)((ptr[0] >> 2) & 0x3F)) |
					((int64)((ptr[1])) << 6);
				data[0] = ((uint32)((ptr[2]))) |
					((uint32)((ptr[3])) << 8);
				ptr += 4;
				return;
			}
			else if ((*ptr & 3) == 2)
			{
				tickDelta = ((int64)((ptr[0] >> 2) & 0x3F)) |
					((int64)((ptr[1])) << 6) |
					((int64)((ptr[2])) << 14) |
					((int64)((ptr[3])) << 22);
				data[0] = ((uint32)((ptr[4]))) |
					((uint32)((ptr[5])) << 8);
				ptr += 6;
				return;
			}
		case 9,10,11,12:
			if ((*ptr & 3) == 0)
			{
				tickDelta = ((int64)((ptr[0] >> 2) & 0x3F));
				data[0] = ((uint32)((ptr[1]))) |
					((uint32)((ptr[2])) << 8) |
					((uint32)((ptr[3])) << 16);
				ptr += 4;
				return;
			}
			else if ((*ptr & 3) == 1)
			{
				tickDelta = ((int64)((ptr[0] >> 2) & 0x3F)) |
					((int64)((ptr[1])) << 6);
				data[0] = ((uint32)((ptr[2]))) |
					((uint32)((ptr[3])) << 8) |
					((uint32)((ptr[4])) << 16);
				ptr += 5;
				return;
			}
			else if ((*ptr & 3) == 2)
			{
				tickDelta = ((int64)((ptr[0] >> 2) & 0x3F)) |
					((int64)((ptr[1])) << 6) |
					((int64)((ptr[2])) << 14) |
					((int64)((ptr[3])) << 22);
				data[0] = ((uint32)((ptr[4]))) |
					((uint32)((ptr[5])) << 8) |
					((uint32)((ptr[6])) << 16);
				ptr += 7;
				return;
			}
		case 13,14,15,16:
			if ((*ptr & 3) == 0)
			{
				tickDelta = ((int64)((ptr[0] >> 2) & 0x3F));
				data[0] = ((uint32)((ptr[1]))) |
					((uint32)((ptr[2])) << 8) |
					((uint32)((ptr[3])) << 16) |
					((uint32)((ptr[4])) << 24);
				ptr += 5;
				return;
			}
			else if ((*ptr & 3) == 1)
			{
				tickDelta = ((int64)((ptr[0] >> 2) & 0x3F)) |
					((int64)((ptr[1])) << 6);
				data[0] = ((uint32)((ptr[2]))) |
					((uint32)((ptr[3])) << 8) |
					((uint32)((ptr[4])) << 16) |
					((uint32)((ptr[5])) << 24);
				ptr += 6;
				return;
			}
			else if ((*ptr & 3) == 2)
			{
				tickDelta = ((int64)((ptr[0] >> 2) & 0x3F)) |
					((int64)((ptr[1])) << 6) |
					((int64)((ptr[2])) << 14) |
					((int64)((ptr[3])) << 22);
				data[0] = ((uint32)((ptr[4]))) |
					((uint32)((ptr[5])) << 8) |
					((uint32)((ptr[6])) << 16) |
					((uint32)((ptr[7])) << 24);
				ptr += 8;
				return;
			}
		case 17,18,19,20,21,22,23,24:
			if ((*ptr & 3) == 0)
			{
				tickDelta = ((int64)((ptr[0] >> 2) & 0x3F));
				data[0] = ((uint32)((ptr[1]))) |
					((uint32)((ptr[2])) << 8) |
					((uint32)((ptr[3])) << 16) |
					((uint32)((ptr[4])) << 24);
				data[1] = ((uint32)((ptr[5]))) |
					((uint32)((ptr[6])) << 8);
				ptr += 7;
				return;
			}
			else if ((*ptr & 3) == 1)
			{
				tickDelta = ((int64)((ptr[0] >> 2) & 0x3F)) |
					((int64)((ptr[1])) << 6);
				data[0] = ((uint32)((ptr[2]))) |
					((uint32)((ptr[3])) << 8) |
					((uint32)((ptr[4])) << 16) |
					((uint32)((ptr[5])) << 24);
				data[1] = ((uint32)((ptr[6]))) |
					((uint32)((ptr[7])) << 8);
				ptr += 8;
				return;
			}
			else if ((*ptr & 3) == 2)
			{
				tickDelta = ((int64)((ptr[0] >> 2) & 0x3F)) |
					((int64)((ptr[1])) << 6) |
					((int64)((ptr[2])) << 14) |
					((int64)((ptr[3])) << 22);
				data[0] = ((uint32)((ptr[4]))) |
					((uint32)((ptr[5])) << 8) |
					((uint32)((ptr[6])) << 16) |
					((uint32)((ptr[7])) << 24);
				data[1] = ((uint32)((ptr[8]))) |
					((uint32)((ptr[9])) << 8);
				ptr += 10;
				return;
			}
		case 25,26,27,28,29,30,31,32:
			if ((*ptr & 3) == 0)
			{
				tickDelta = ((int64)((ptr[0] >> 2) & 0x3F));
				data[0] = ((uint32)((ptr[1]))) |
					((uint32)((ptr[2])) << 8) |
					((uint32)((ptr[3])) << 16) |
					((uint32)((ptr[4])) << 24);
				data[1] = ((uint32)((ptr[5]))) |
					((uint32)((ptr[6])) << 8) |
					((uint32)((ptr[7])) << 16) |
					((uint32)((ptr[8])) << 24);
				ptr += 9;
				return;
			}
			else if ((*ptr & 3) == 1)
			{
				tickDelta = ((int64)((ptr[0] >> 2) & 0x3F)) |
					((int64)((ptr[1])) << 6);
				data[0] = ((uint32)((ptr[2]))) |
					((uint32)((ptr[3])) << 8) |
					((uint32)((ptr[4])) << 16) |
					((uint32)((ptr[5])) << 24);
				data[1] = ((uint32)((ptr[6]))) |
					((uint32)((ptr[7])) << 8) |
					((uint32)((ptr[8])) << 16) |
					((uint32)((ptr[9])) << 24);
				ptr += 10;
				return;
			}
			else if ((*ptr & 3) == 2)
			{
				tickDelta = ((int64)((ptr[0] >> 2) & 0x3F)) |
					((int64)((ptr[1])) << 6) |
					((int64)((ptr[2])) << 14) |
					((int64)((ptr[3])) << 22);
				data[0] = ((uint32)((ptr[4]))) |
					((uint32)((ptr[5])) << 8) |
					((uint32)((ptr[6])) << 16) |
					((uint32)((ptr[7])) << 24);
				data[1] = ((uint32)((ptr[8]))) |
					((uint32)((ptr[9])) << 8) |
					((uint32)((ptr[10])) << 16) |
					((uint32)((ptr[11])) << 24);
				ptr += 12;
				return;
			}
		case 33,34,35,36,37,38,39,40:
			if ((*ptr & 3) == 0)
			{
				tickDelta = ((int64)((ptr[0] >> 2) & 0x3F));
				data[0] = ((uint32)((ptr[1]))) |
					((uint32)((ptr[2])) << 8) |
					((uint32)((ptr[3])) << 16) |
					((uint32)((ptr[4])) << 24);
				data[1] = ((uint32)((ptr[5]))) |
					((uint32)((ptr[6])) << 8) |
					((uint32)((ptr[7])) << 16) |
					((uint32)((ptr[8])) << 24);
				data[2] = ((uint32)((ptr[9]))) |
					((uint32)((ptr[10])) << 8);
				ptr += 11;
				return;
			}
			else if ((*ptr & 3) == 1)
			{
				tickDelta = ((int64)((ptr[0] >> 2) & 0x3F)) |
					((int64)((ptr[1])) << 6);
				data[0] = ((uint32)((ptr[2]))) |
					((uint32)((ptr[3])) << 8) |
					((uint32)((ptr[4])) << 16) |
					((uint32)((ptr[5])) << 24);
				data[1] = ((uint32)((ptr[6]))) |
					((uint32)((ptr[7])) << 8) |
					((uint32)((ptr[8])) << 16) |
					((uint32)((ptr[9])) << 24);
				data[2] = ((uint32)((ptr[10]))) |
					((uint32)((ptr[11])) << 8);
				ptr += 12;
				return;
			}
			else if ((*ptr & 3) == 2)
			{
				tickDelta = ((int64)((ptr[0] >> 2) & 0x3F)) |
					((int64)((ptr[1])) << 6) |
					((int64)((ptr[2])) << 14) |
					((int64)((ptr[3])) << 22);
				data[0] = ((uint32)((ptr[4]))) |
					((uint32)((ptr[5])) << 8) |
					((uint32)((ptr[6])) << 16) |
					((uint32)((ptr[7])) << 24);
				data[1] = ((uint32)((ptr[8]))) |
					((uint32)((ptr[9])) << 8) |
					((uint32)((ptr[10])) << 16) |
					((uint32)((ptr[11])) << 24);
				data[2] = ((uint32)((ptr[12]))) |
					((uint32)((ptr[13])) << 8);
				ptr += 14;
				return;
			}
		case 41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64:
			if ((*ptr & 3) == 0)
			{
				tickDelta = ((int64)((ptr[0] >> 2) & 0x3F));
				data[0] = ((uint32)((ptr[1]))) |
					((uint32)((ptr[2])) << 8) |
					((uint32)((ptr[3])) << 16) |
					((uint32)((ptr[4])) << 24);
				data[1] = ((uint32)((ptr[5]))) |
					((uint32)((ptr[6])) << 8) |
					((uint32)((ptr[7])) << 16) |
					((uint32)((ptr[8])) << 24);
				data[2] = ((uint32)((ptr[9]))) |
					((uint32)((ptr[10])) << 8) |
					((uint32)((ptr[11])) << 16) |
					((uint32)((ptr[12])) << 24);
				data[3] = ((uint32)((ptr[13]))) |
					((uint32)((ptr[14])) << 8) |
					((uint32)((ptr[15])) << 16) |
					((uint32)((ptr[16])) << 24);
				ptr += 17;
				return;
			}
			else if ((*ptr & 3) == 1)
			{
				tickDelta = ((int64)((ptr[0] >> 2) & 0x3F)) |
					((int64)((ptr[1])) << 6);
				data[0] = ((uint32)((ptr[2]))) |
					((uint32)((ptr[3])) << 8) |
					((uint32)((ptr[4])) << 16) |
					((uint32)((ptr[5])) << 24);
				data[1] = ((uint32)((ptr[6]))) |
					((uint32)((ptr[7])) << 8) |
					((uint32)((ptr[8])) << 16) |
					((uint32)((ptr[9])) << 24);
				data[2] = ((uint32)((ptr[10]))) |
					((uint32)((ptr[11])) << 8) |
					((uint32)((ptr[12])) << 16) |
					((uint32)((ptr[13])) << 24);
				data[3] = ((uint32)((ptr[14]))) |
					((uint32)((ptr[15])) << 8) |
					((uint32)((ptr[16])) << 16) |
					((uint32)((ptr[17])) << 24);
				ptr += 18;
				return;
			}
			else if ((*ptr & 3) == 2)
			{
				tickDelta = ((int64)((ptr[0] >> 2) & 0x3F)) |
					((int64)((ptr[1])) << 6) |
					((int64)((ptr[2])) << 14) |
					((int64)((ptr[3])) << 22);
				data[0] = ((uint32)((ptr[4]))) |
					((uint32)((ptr[5])) << 8) |
					((uint32)((ptr[6])) << 16) |
					((uint32)((ptr[7])) << 24);
				data[1] = ((uint32)((ptr[8]))) |
					((uint32)((ptr[9])) << 8) |
					((uint32)((ptr[10])) << 16) |
					((uint32)((ptr[11])) << 24);
				data[2] = ((uint32)((ptr[12]))) |
					((uint32)((ptr[13])) << 8) |
					((uint32)((ptr[14])) << 16) |
					((uint32)((ptr[15])) << 24);
				data[3] = ((uint32)((ptr[16]))) |
					((uint32)((ptr[17])) << 8) |
					((uint32)((ptr[18])) << 16) |
					((uint32)((ptr[19])) << 24);
				ptr += 20;
				return;
			}

		default:
			int32 numBytes = (mNumBits * 2 + 7) / 8;
			if ((*ptr & 3) == 0)
			{
				tickDelta = ((int64)((ptr[0] >> 2) & 0x3F));
				Internal.MemCpy(data, ptr + 1, numBytes);
				ptr += 1 + numBytes;
				return;
			}
			else if ((*ptr & 3) == 1)
			{
				tickDelta = ((int64)((ptr[0] >> 2) & 0x3F)) |
					((int64)((ptr[1])) << 6);
				Internal.MemCpy(data, ptr + 2, numBytes);
				ptr += 2 + numBytes;
				return;
			}
			else if ((*ptr & 3) == 2)
			{
				tickDelta = ((int64)((ptr[0] >> 2) & 0x3F)) |
					((int64)((ptr[1])) << 6) |
					((int64)((ptr[2])) << 14) |
					((int64)((ptr[3])) << 22);
				Internal.MemCpy(data, ptr + 4, numBytes);
				ptr += 4 + numBytes;
				return;
			}
		}

		switch (ptr[0])
		{
		case 3 | 4:
			int32 numBytes = (mNumBits * 2 + 7) / 8;
			tickDelta = *(int64*)(ptr + 1);
			Debug.Assert(tickDelta <= gApp.mSigData.mEndTick);
			Internal.MemCpy(data, ptr + 1 + 8, numBytes);
			ptr += 1 + 8 + numBytes;
		default:
			Debug.FatalError("Decode failed");
		}
	}
}

public class SignalChunk
{
	public SignalData mSignalData;
	public int64 mStartTick = -1;
	public int64 mEndTick = -1;
	public SignalChunkData mRawData = new .() ~ delete _;
	public List<SignalChunkData> mLODData = new .() ~ DeleteContainerAndItems!(_);
	public List<int16> mLODIndices = new .() ~ delete _;

	public this(SignalData signalData)
	{
		mSignalData = signalData;
		mRawData.mNumBits = signalData.mNumBits;
	}

	void PopulateLodIdx(int lodIdx, int64 minTickDelta)
	{
		for (int pow2 = 0; pow2 < 32; pow2++)
		{
			int64 lodFactor = 1<<pow2;
			if (lodFactor > minTickDelta)
				break;

			if (pow2 >= mLODIndices.Count)
				mLODIndices.Add((.)lodIdx);
		}
	}

	public void GenerateNextLOD()
	{
		SignalChunkData srcData = mRawData;
		if (!mLODData.IsEmpty)
			srcData = mLODData.Back;

		int wantMinTickDelta = Math.Max((srcData.mMinDelta + srcData.mDeltaEncodeOffset) * 2, 2);

		int lodIdx = mLODData.Count;

		SignalChunkData lodData = new .(srcData.mBuffer.Count / 8);
		lodData.mNumBits = srcData.mNumBits;
		lodData.mStartTick = srcData.mStartTick;
		lodData.mEndTick = srcData.mStartTick;
		lodData.mDeltaEncodeOffset = wantMinTickDelta;
		mLODData.Add(lodData);

		uint32[2][4096] decodedDataBuf = ?;
		var signalData = mSignalData;
		int decodeIdx = 0;
		int encodeIdx = 0;

		int64 lastEncodedTick = srcData.mStartTick;
		int64 queuedEncodeTick = srcData.mStartTick;

		uint32* decodedData = null;
		uint32* prevDecodedData = null;
		
		int64 curTick = srcData.mStartTick;

		void Encode(int64 tick, uint32* data)
		{
			// Commit queued tick
			int64 lodTickDelta = tick - lastEncodedTick;
			if (encodeIdx > 0)
			{
				Debug.Assert(lodTickDelta >= lodData.mDeltaEncodeOffset);
				lodTickDelta -= lodData.mDeltaEncodeOffset;
			}

			lodData.Encode(lodTickDelta, data);
			lastEncodedTick = tick;
			encodeIdx++;
		}

		uint8* chunkPtr = srcData.mBuffer.Ptr;
		uint8* chunkEndPtr = chunkPtr + srcData.mBuffer.Count;
		while (chunkPtr < chunkEndPtr)
		{
			decodedData = &decodedDataBuf[decodeIdx % 2];
			prevDecodedData = &decodedDataBuf[(decodeIdx % 2) ^ 1];

			// Zero out trailing fill bits in the last signal word 
			decodedData[signalData.mNumBits/16] = 0;

			srcData.Decode(ref chunkPtr, decodedData, var tickDelta);
			if (decodeIdx > 0)
			{
				tickDelta >>= srcData.mDeltaShift;
				tickDelta += srcData.mDeltaEncodeOffset;
			}

			curTick += tickDelta;

			if (curTick - queuedEncodeTick >= wantMinTickDelta)
			{
				Encode(queuedEncodeTick, prevDecodedData);
				queuedEncodeTick = curTick;
			}

			decodeIdx++;
		}

		Encode(curTick, decodedData);

		PopulateLodIdx(lodIdx, lodData.mMinDelta + lodData.mDeltaEncodeOffset);
	}

	public void Finish()
	{
		mStartTick = mRawData.mStartTick;
		mEndTick = mRawData.mEndTick;

		if (mRawData.mMinDelta == Int64.MaxValue)
		{
			NOP!();
		}

		mRawData.Finish();

		PopulateLodIdx(-1, Math.Max(mRawData.mMinDelta + mRawData.mDeltaEncodeOffset, 1));
	}
}

public class SignalData : RefCounted
{
	public List<SignalChunk> mChunks = new .() ~ DeleteContainerAndItems!(_);
	public SignalChunkData mCurChunkData;
	public int32 mNumBits;
	public int32 mMaxEncodeSize;

	public this(int32 numBits)
	{
		mNumBits = numBits;
		mMaxEncodeSize = mNumBits / 8 + 6;

		var signalChunk = new SignalChunk(this);
		mCurChunkData = signalChunk.mRawData;
		mChunks.Add(signalChunk);
	}

	public void Encode(int64 tick, uint32* data)
	{
		var chunk = mCurChunkData;
		
		if (chunk.mStartTick == -1)
		{
			chunk.mStartTick = tick;
			chunk.mEndTick = tick;
		}
		else
		{
			if (chunk.mBuffer.[Friend]mSize >= SignalChunkData.cDataSize - mMaxEncodeSize)
			{
				var signalChunk = new SignalChunk(this);
				mCurChunkData = signalChunk.mRawData;
				mCurChunkData.mStartTick = tick;
				mCurChunkData.mEndTick = tick;
				mChunks.Add(signalChunk);
				chunk = mCurChunkData;
			}
		}

		int64 tickDelta = tick - chunk.mEndTick;
		Debug.Assert(tickDelta >= 0);
		chunk.Encode(tickDelta, data);
		chunk.mEndTick = tick;
	}

	public void Finish()
	{
		mChunks.Back.mRawData.mEndTick = gApp.mSigData.mEndTick;

		for (var chunk in mChunks)
		{
			chunk.Finish();
		}
	}
}

public enum SignalKind
{
	Wire,
	Reg,
	Parameter
}

public class Signal
{
	public SignalGroup mGroup;
	public SignalKind mKind;
	public String mName ~ delete _;
	public String mDims ~ delete _;
	public int32 mBits;

	public SignalData mSignalData;

	public ~this()
	{
		mSignalData.ReleaseRef();
	}

	public void GetFullName(String outName)
	{
		mGroup.GetFullName(outName);
		outName.Append('/');
		outName.Append(mName);
	}

	public void Finish()
	{
		mSignalData.Finish();
	}
}

public class SignalGroup
{
	public SignalGroup mGroup;
	public String mName = new .() ~ delete _;
	public List<SignalGroup> mNestedGroups ~ DeleteContainerAndItems!(_);
	public List<Signal> mSignals = new .() ~ DeleteContainerAndItems!(_);
	public Dictionary<String, SignalGroup> mGroupMap ~ delete _;
	public Dictionary<String, Signal> mSignalMap = new .() ~ delete _;

	public void GetFullName(String outName)
	{
		if ((mGroup != null) && (mGroup.mGroup != null))
		{
			mGroup.GetFullName(outName);
			outName.Append('/');
		}
		outName.Append(mName);
	}

	public SignalGroup GetGroup(StringView name)
	{
		if (mGroupMap.TryGetValueAlt(name, var value))
			return value;
		return null;
	}

	public Signal GetSignal(StringView name)
	{
		if (mSignalMap.TryGetValueAlt(name, var value))
			return value;
		return null;
	}

	public void Finish()
	{
		if (mNestedGroups != null)
		{
			for (var subGroup in mNestedGroups)
				subGroup.Finish();
		}

		for (var signal in mSignals)
			signal.Finish();
	}
}

class SigData
{
	struct VCDVarData
	{
		public StringView mKind;
		public int32 mNumBits;
		public int32 mID;
		public StringView mName;
		public StringView mDims;
	}

	enum VCDState
	{
		case None;
		case Unknown;
		case Comment;
		case Scope(int32 dataIdx);
		case Var(int32 dataIdx);
		case Timescale;
	}


	public SignalGroup mRoot ~ delete _;
	public int64 mStartTick;
	public int64 mEndTick;
	public double mTimescale = 1e-9; // 1ns

	public int64 TickCount => mEndTick - mStartTick;

	public Result<void> Load(StringView filePath)
	{
		UnbufferedFileStream fs = scope .();
		if (fs.Open(filePath, .Read) case .Err)
			return .Err;

		mRoot = new .();

		int32 chunkSize = 1024 * 1024;

		char8* data = new char8[chunkSize + 8 * 2]*;
		defer delete data;

		// Terminate chunk with sequence that will reduce paring special cases
		for (int i < 8)
		{
			data[chunkSize + i * 2] = 0;
			data[chunkSize + i * 2 + 1] = '?';
		}

		VCDState parseState = .None;
		VCDVarData varData = default;
		List<SignalData> signalDataMap = scope .();
		defer
		{
			for (var signalData in signalDataMap)
				signalData?.ReleaseRef();
		}

		List<SignalGroup> signalGroupStack = scope .();
		signalGroupStack.Add(mRoot);

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
							mStartTick = newTick;
							isFirstTick = false;
						}
						Debug.Assert(newTick >= tick);
						tick = newTick;
						mEndTick = tick;

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
									mStartTick = tick;
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
								mTimescale = val * scale;
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

		mRoot.Finish();

		return .Ok;
	}

	public Signal GetSignal(String signalPath)
	{
		SignalGroup curGroup = mRoot;
		for (var name in signalPath.Split('/'))
		{
			if (@name.HasMore)
			{
				curGroup = curGroup.GetGroup(name);
				if (curGroup == null)
					return null;
			}
			else
				return curGroup.GetSignal(name);
		}
		return null;
	}
}
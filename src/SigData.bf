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
	public int64 mWantMinTickDelta;

	public int64 MinDeltaTick => mMinDelta + mDeltaEncodeOffset;

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
	public const int32 cMaxLODSelector = 32;

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

	void PopulateLODIdx(int lodIdx, int64 minTickDelta)
	{
		for (int pow2 = 0; pow2 < cMaxLODSelector + 1; pow2++)
		{
			int64 lodFactor = 1<<pow2;
			if (lodFactor > minTickDelta)
				break;
			if (pow2 >= mLODIndices.Count)
			{
				if ((minTickDelta > lodFactor) && (lodIdx > 0))
				{
					mLODIndices.Add((.)lodIdx - 1);
				}
				else
					mLODIndices.Add((.)lodIdx);
			}
		}
	}

	public void GenerateNextLOD()
	{
		SignalChunkData srcData = mRawData;
		if (!mLODData.IsEmpty)
			srcData = mLODData.Back;

		int wantMinTickDelta = Math.Max((srcData.mMinDelta + srcData.mDeltaEncodeOffset) * 3, 3);

		int lodIdx = mLODData.Count;

		SignalChunkData lodData = new .(srcData.mBuffer.Count / 8);
		lodData.mNumBits = srcData.mNumBits;
		lodData.mStartTick = srcData.mStartTick;
		lodData.mEndTick = srcData.mStartTick;
		lodData.mDeltaEncodeOffset = wantMinTickDelta;
		lodData.mWantMinTickDelta = wantMinTickDelta;
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

		PopulateLODIdx(lodIdx, lodData.mMinDelta + lodData.mDeltaEncodeOffset);

		if (lodData.MinDeltaTick == srcData.MinDeltaTick)
		{
			// Sanity check to ensure progress
			mLODIndices.Add((.)lodIdx);
		}
	}

	public void Finish()
	{
		mStartTick = mRawData.mStartTick;
		mEndTick = mRawData.mEndTick;
		mRawData.Finish();

		PopulateLODIdx(-1, Math.Max(mRawData.mMinDelta + mRawData.mDeltaEncodeOffset, 1));
	}
}

public class SignalData : RefCounted
{
	public Signal mFirstRef;
	public List<SignalChunk> mChunks = new .() ~ DeleteContainerAndItems!(_);
	public List<String> mStrings ~ DeleteContainerAndItems!(_);
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
	public int32 mNumBits;

	public SignalData mSignalData;

	public ~this()
	{
		mSignalData.ReleaseRef();
	}

	public void GetFullName(String outName)
	{
		if ((mGroup != null) && (mGroup.mGroup != null))
		{
			mGroup.GetFullName(outName);
			outName.Append('.');
		}
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
	public bool mSortDirty;

	public void GetFullName(String outName)
	{
		if ((mGroup != null) && (mGroup.mGroup != null))
		{
			mGroup.GetFullName(outName);
			outName.Append('.');
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
	public SignalGroup mRoot ~ delete _;
	public int64 mStartTick;
	public int64 mEndTick;
	public double mTimescale = 1e-9; // 1ns

	public int64 TickCount => mEndTick - mStartTick;

	public Signal GetSignal(String signalPath)
	{
		SignalGroup curGroup = mRoot;
		for (var name in signalPath.Split('.'))
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
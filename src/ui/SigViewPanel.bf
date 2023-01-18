using Beefy.gfx;
using System;
namespace SigBuddy.ui;

class SigViewPanel : Panel
{
	public double mScale = 1.0f;
	public double mTickOfs = 0;

	public float GetTickX(int64 tick)
	{
		return (.)((tick - gApp.mSigData.mStartTick - mTickOfs) * mScale);
	}

	public override void Draw(Graphics g)
	{
		uint32[2][4096] decodedDataBuf = ?;

		g.SetFont(gApp.mSmFont);

		for (var entry in gApp.mSigPanel.mEntries)
		{
			//float curX = 0;
			float curY = @entry.Index * 20 + 20;

			/*using (g.PushColor(0xFF00FF00))
			{
				g.FillRect(curX, curY, 50, 18);
			}*/

			int64 lastTick = 0;
			int decodeIdx = 0;
			
			var signalData = entry.mSignal.mSignalData;
			int32 numSignalWords = (signalData.mNumBits + 15) / 16;

			if (!signalData.mChunks.IsEmpty)
			{
				lastTick = signalData.mChunks.Front.mStartTick;
			}
			float prevSigX = GetTickX(lastTick);

			Internal.MemSet(&decodedDataBuf[1], 0xFF, (signalData.mNumBits + 7)/8);

			void Draw(float x, float width, uint32* decodedData)
			{
				//bool sigHas

				bool hasUndefined = false;
				bool isNonZero = false;

				for (var dataIdx < numSignalWords)
				{
					if ((decodedData[dataIdx] & 0xAAAAAAAA) != 0)
						hasUndefined = true;
					if ((decodedData[dataIdx] & 0x55555555) != 0)
						isNonZero = true;
				}

				bool useAngled = signalData.mNumBits > 1;

				uint32 color = entry.mColor;

				if (hasUndefined)
				{
					Color.ToHSV(color, var h, var s, var v);

					s *= 0.2f;
					v *= 0.5f;

					color = Color.FromHSV(h, s, v, 255);
				}

				using (g.PushColor(color))
				{
					if (isNonZero)
					{
						if (width < 3.5f)
						{
							g.Draw(gApp.mSigBar, x, curY);
						}
						else
						{
							SigUIImage imageKind = useAngled ? .SigFullAngled : .SigFull;
							if ((useAngled) && (width < 7))
								imageKind = .SigFullAngledShort;

							g.DrawButton(gApp.mSigUIImages[(.)imageKind], x, curY, width);
						}
					}
					else
					{
						//g.FillRect(x, curY, width, 18);
						g.DrawButton(gApp.mSigUIImages[useAngled ? (.)SigUIImage.SigEmptyAngled :
							(.)SigUIImage.SigEmpty], x, curY, width);
					}
				}

				//g.Draw(gApp.mSigBar, x, curY);
				
				
				if (signalData.mNumBits > 1)
				{
					if (width > 20)
					{
						String drawStr = scope .(64);
						drawStr.Append("012ABF");
						g.DrawString("012ABF", x + 5, curY + 5, .Left, width - 7, .Ellipsis);
					}
					else if (width > 11)
					{
						g.DrawString("+", Math.Min(x + 5, x + width / 2 - 3), curY + 5);
					}
				}
			}

			for (var chunk in signalData.mChunks)
			{
				int64 curTick = chunk.mStartTick;

				uint8* chunkPtr = chunk.mBuffer.Ptr;
				uint8* chunkEndPtr = chunkPtr + chunk.mBuffer.Count;
				while (chunkPtr < chunkEndPtr)
				{
					uint32* decodedData = &decodedDataBuf[decodeIdx % 2];
					uint32* prevDecodedData = &decodedDataBuf[(decodeIdx % 2) ^ 1];

					// Zero out trailing fill bits in the last signal word 
					decodedData[signalData.mNumBits/16] = 0;

					signalData.Decode(ref chunkPtr, decodedData, var tickDelta);
					curTick += tickDelta;

					float sigX = GetTickX(curTick);

					Draw(prevSigX, sigX - prevSigX + 1, prevDecodedData);

					prevSigX = sigX;

					decodeIdx++;
				}
			}

			uint32* prevDecodedData = &decodedDataBuf[(decodeIdx % 2) ^ 1];
			float sigX = GetTickX(gApp.mSigData.mEndTick);
			Draw(prevSigX, sigX - prevSigX + 1, prevDecodedData);
		}
	}

	public override void MouseWheel(float x, float y, float deltaX, float deltaY)
	{
		base.MouseWheel(x, y, deltaX, deltaY);

		for (int i < (int)deltaY)
		{
			if (mWidgetWindow.IsKeyDown(.Shift))
				mScale *= 1.01f;
			else
				mScale *= 1.1f;
		}

		for (int i < (int)-deltaY)
		{
			if (mWidgetWindow.IsKeyDown(.Shift))
				mScale /= 1.01f;
			else
				mScale /= 1.1f;
		}
	}
}
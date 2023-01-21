using System;
using Beefy.gfx;
using Beefy.widgets;
using Beefy.theme.dark;
using Beefy.theme;
using System.Diagnostics;
using Beefy.geom;

namespace SigBuddy.ui;

class SigViewPanel : Panel
{
	public DarkScrollbar mHorzScrollbar;
	public DarkScrollbar mVertScrollbar;
	public double mScale = 1.0f;
	public double mTickOfs = 0;
	public double? mCursorTick;

	Point? mMousePos;
	float mMouseDownX;
	float mMouseDownY;

	public this()
	{
		mClipGfx = true;
		mHorzScrollbar = (.)ThemeFactory.mDefault.CreateScrollbar(Scrollbar.Orientation.Horz);
		mVertScrollbar = (.)ThemeFactory.mDefault.CreateScrollbar(Scrollbar.Orientation.Vert);

		AddWidget(mHorzScrollbar);
		AddWidget(mVertScrollbar);

		mHorzScrollbar.mOnScrollEvent.Add(new (evt) =>
			{
				mTickOfs = evt.mNewPos;
			});
		mVertScrollbar.mOnScrollEvent.Add(new (evt) =>
			{
				//gApp.mSigPanel.mSigActiveListPanel.mListView.UpdateContentPosition();
				var scrollContent = gApp.mSigPanel.mSigActiveListPanel.mListView.mScrollContent;
				scrollContent.Resize(
					0,
					//(int32)(-mVertPos.v - (mVertScrollbar?.mContentStart).GetValueOrDefault()),
					(.)-evt.mNewPos,
					scrollContent.mWidth, scrollContent.mHeight);
			});

		UpdateScrollbar();
	}

	//public int TrailingTicks = Math.Min(gApp.mSigData.TickCount / 10, 100);
	//public int TrailingTicks = (.)(100 * mScale);
	public int TrailingTicks => (.)(100 / mScale);

	public float GetTickX(int64 tick)
	{
		return (.)((tick - gApp.mSigData.mStartTick - mTickOfs) * mScale);
	}

	public float GetTickX(double tick)
	{
		return (.)((tick - gApp.mSigData.mStartTick - mTickOfs) * mScale);
	}

	public float GetTimeX(double time)
	{
		double tick = time / gApp.mSigData.mTimescale;
		return (.)((tick - gApp.mSigData.mStartTick - mTickOfs) * mScale);
	}

	public double GetTickAt(float x)
	{
		return x / mScale + gApp.mSigData.mStartTick + mTickOfs;
	}

	public double GetTimeAt(float x)
	{
		return (x / mScale + gApp.mSigData.mStartTick + mTickOfs) * gApp.mSigData.mTimescale;
	}

	void DrawTimeline(Graphics g)
	{
		double checkScale = gApp.mSigData.mTimescale / mScale;

		double sectionScale = gApp.mSigData.mTimescale;

		for (int i in -15...1)
		{
			double tryScale = Math.Pow(10, i);

			if (tryScale >= checkScale * 60)
			{
				sectionScale = tryScale;
				break;
			}

			//if (checkScale > )
		}

		double zeroTime = GetTimeAt(0);

		String timeStr = scope .();

		int i = (.)(zeroTime / sectionScale);
		while (true)
		{
			double time = i * sectionScale;
			float x = GetTimeX(time);

			if (x > mWidth)
				break;

			if (GetTickAt(x) > gApp.mSigData.mEndTick)
				break;

			using (g.PushColor(0x308080FF))
				g.FillRect(x, 0, 1, mHeight);

			if (time != 0)
			{
				timeStr.Clear();
				Utils.TimeToStr(time, timeStr);
				g.DrawString(timeStr, x, 5, .Centered);
			}

			i++;
		}
	}

	public void DrawSignals(Graphics g)
	{
		uint32[2][4096] decodedDataBuf = ?;

		int minDrawTick = (.)GetTickAt(0);

		int lodTickTarget = (.)(2.0f / mScale);
		int lodScale = 0;

		while (1<<(lodScale + 1) <= lodTickTarget)
			lodScale++;
		
		for (var entry in gApp.mSigPanel.mEntries)
		{
			//float curX = 0;
			//float curY = @entry.Index * 20 + 20;
			float curY = entry.mY;

			/*using (g.PushColor(0xFF00FF00))
			{
				g.FillRect(curX, curY, 50, 18);
			}*/

			bool drewSigBar = false;
			float lastDrawEndX = -1000;
			int64 lastTick = 0;
			int decodeIdx = 0;

			int64 minNextTick = 0;
			
			var signalData = entry.mSignal.mSignalData;
			int32 numSignalWords = (signalData.mNumBits + 15) / 16;

			if (!signalData.mChunks.IsEmpty)
			{
				lastTick = signalData.mChunks.Front.mStartTick;
				if (lastTick < 0)
					lastTick = gApp.mSigData.mStartTick;
			}
			float prevSigX = GetTickX(lastTick);

			Internal.MemSet(&decodedDataBuf[1], 0xFF, (signalData.mNumBits + 7)/8);

			void Draw(float x, float endX, uint32* decodedData)
			{
				bool lastWasBar = drewSigBar;
				drewSigBar = false;

				float drawX = (int32)x;
				//float drawWidth = (int64)endX - (int64)x;
				float drawWidth = (int64)endX - (int64)x;

				if (drawWidth < 2)
					drawWidth = 2;

				float drawEndX = drawX + drawWidth;
				if (drawEndX < 0)
					return;

				float endXDelta = drawEndX - lastDrawEndX;

				if (endXDelta < 2.0f)
				{
					if (endXDelta >= 0.0f)
					{
						using (g.PushColor(entry.mColor))
							g.Draw(gApp.mSigBar, lastDrawEndX, curY);

						lastDrawEndX += 3;
						minNextTick = (.)GetTickAt(lastDrawEndX);
						drewSigBar = true;

						return;
					}
					else
					{
						return;
					}
				}

				if (drawX < -100000)
				{
					drawX = -100000;
					drawWidth = (int64)endX - (int64)drawX;
				}
				if (drawWidth > 200000)
					drawWidth = 200000;


				var origLastDrawEndX = lastDrawEndX;
				lastDrawEndX = drawEndX;
				
				
				/*if (drawX - lastDrawX < 2.5)
					return;
				lastDrawX = drawX;*/


				//bool sigHas

				bool hasUndefined = false;
				bool isNonZero = false;

				for (var dataIdx < numSignalWords)
				{
					if ((decodedData[dataIdx] & 0xAAAAAAAA) != 0)
						hasUndefined = true;
					if (decodedData[dataIdx] != 0)
						isNonZero = true;
				}

				bool useAngled = signalData.mNumBits > 1;

				uint32 color = entry.mColor;

				if (hasUndefined)
				{
					if (entry.mColorUndef == 0)
					{
						Color.ToHSV(color, var h, var s, var v);
						s *= 0.2f;
						v *= 0.5f;
						entry.mColorUndef = Color.FromHSV(h, s, v, 255);
					}
					color = entry.mColorUndef;
				}

				using (g.PushColor(color))
				{
					

					if (isNonZero)
					{
						if ((drawWidth < 4.5f) /*&& (!mWidgetWindow.IsKeyDown(.Shift))*/)
						{
							g.Draw(gApp.mSigBar, drawX, curY);
							drewSigBar = true;
							//lastDrawEndX = drawX + Math.Max(drawWidth, 3);
							lastDrawEndX = drawX + 3;
						}
						else
						{
							if (lastWasBar)
							{
								drawX = origLastDrawEndX;
								drawWidth = (int64)endX - (int64)drawX;

								//int ofs = (.)(lastDrawEndX - drawX - 1);
								//drawX -= ofs;
								//drawWidth += ofs;

								//drawX -= 1;
							}

							SigUIImage imageKind = useAngled ? .SigFullAngled : .SigFull;
							if ((useAngled) && (drawWidth < 7))
								imageKind = .SigFullAngledShort;

							g.DrawButton(gApp.mSigUIImages[(.)imageKind], drawX, curY, drawWidth);
						}
					}
					else
					{
						if (lastWasBar)
						{
							drawX = origLastDrawEndX;
							drawWidth = (int64)endX - (int64)drawX;

							//int ofs = (.)(lastDrawEndX - drawX - 1);
							//drawX -= ofs;
							//drawWidth += ofs;

							//drawX -= 1;
						}

						//g.FillRect(x, curY, width, 18);
						g.DrawButton(gApp.mSigUIImages[useAngled ? (.)SigUIImage.SigEmptyAngled :
							(.)SigUIImage.SigEmpty], drawX, curY, drawWidth);
					}
				}

				//g.Draw(gApp.mSigBar, x, curY);
				
				if ((signalData.mNumBits > 1) || (hasUndefined))
				{
					if (drawWidth > 20)
					{
						String drawStr = scope .(64);
						entry.GetValueString(decodedData, drawStr, false);
						g.DrawString(drawStr, drawX + 5, curY + 5, .Left, drawWidth - 7, .Ellipsis);
					}
					else if (drawWidth > 11)
					{
						g.DrawString("+", Math.Min(drawX + 5, drawX + drawWidth / 2 - 3), curY + 5);
					}
				}
			}

			ChunkLoop: for (var chunk in signalData.mChunks)
			{
				if (chunk.mEndTick < minDrawTick)
					continue;

				int64 curTick = chunk.mStartTick;

				var chunkData = chunk.mRawData;
				int lodIdx = -1;

				if (mWidgetWindow.IsKeyDown((.)'0'))
					lodIdx = -1;
				else if (mWidgetWindow.IsKeyDown((.)'1'))
					lodIdx = 0;
				else if (mWidgetWindow.IsKeyDown((.)'2'))
					lodIdx = 1;
				else if (mWidgetWindow.IsKeyDown((.)'3'))
					lodIdx = 2;
				else
				{
					while (lodScale >= chunk.mLODIndices.Count)
						chunk.GenerateNextLOD();
					lodIdx = chunk.mLODIndices[lodScale];
				}

				if (lodIdx != -1)
				{
					while (lodIdx >= chunk.mLODData.Count)
						chunk.GenerateNextLOD();

					chunkData = chunk.mLODData[lodIdx];

					/*if (!chunk.mLODData.IsEmpty)
					{
						chunkData = chunk.mLODData[0];
					}*/
					/*else
						continue;*/
				}

				/*if (lodIdx == -1)
					entry.mColor = 0xFF00FF00;
				else if (lodIdx == 0)
					entry.mColor = 0xFFFF0000;
				else if (lodIdx == 1)
					entry.mColor = 0xFF0000FF;
				else
					entry.mColor = 0xFFFFFF00;*/

				int32 chunkDecodeIdx = 0;
				uint8* chunkPtr = chunkData.mBuffer.Ptr;
				uint8* chunkEndPtr = chunkPtr + chunkData.mBuffer.Count;
				while (chunkPtr < chunkEndPtr)
				{
					uint32* decodedData = &decodedDataBuf[decodeIdx % 2];
					uint32* prevDecodedData = &decodedDataBuf[(decodeIdx % 2) ^ 1];

					// Zero out trailing fill bits in the last signal word 
					decodedData[signalData.mNumBits/16] = 0;

					chunkData.Decode(ref chunkPtr, decodedData, var tickDelta);
					if (chunkDecodeIdx > 0)
					{
						tickDelta >>= chunkData.mDeltaShift;
						tickDelta += chunkData.mDeltaEncodeOffset;
					}

					curTick += tickDelta;

					if (curTick >= minNextTick)
					{
						float sigX = GetTickX(curTick);

						if (decodeIdx != 0)
							Draw(prevSigX, sigX, prevDecodedData);
						
						prevSigX = sigX;
					}
					
					decodeIdx++;
					chunkDecodeIdx++;

					if (prevSigX > mWidth)
						break ChunkLoop;
				}
			}

			uint32* prevDecodedData = &decodedDataBuf[(decodeIdx % 2) ^ 1];
			float sigX = GetTickX(gApp.mSigData.mEndTick);
			if (prevSigX < mWidth)
				Draw(prevSigX, sigX, prevDecodedData);
		}
	}

	public override void Draw(Graphics g)
	{
		g.SetFont(gApp.mSmFont);
		DrawTimeline(g);

		using (g.PushClip(0, GS!(18), mWidth, mHeight - GS!(36)))
			using (g.PushTranslate(0, (.)-mVertScrollbar.mContentPos))
				DrawSignals(g);

		if (mCursorTick != null)
		{
			float x = GetTickX(mCursorTick.Value);
			using (g.PushColor(0xA0FFA0C0))
				g.FillRect(x, 0, 1, mHeight);
		}
	}

	public override void MouseWheel(float x, float y, float deltaX, float deltaY)
	{
		base.MouseWheel(x, y, deltaX, deltaY);

		float centerX = x;

		// Make it easier to maintain left-hand side
		if (centerX < 32)
			centerX = 0;

		double xTick = GetTickAt(centerX);

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

		Clamp();

		mTickOfs = (xTick - gApp.mSigData.mStartTick) + -centerX / mScale;

		if (mTickOfs < 0)
			mTickOfs = 0;

		UpdateScrollbar();
		Clamp();
	}

	public override void MouseDown(float x, float y, int32 btn, int32 btnCount)
	{
		base.MouseDown(x, y, btn, btnCount);

		mMouseDownX = x;
		mMouseDownY = y;
		mMousePos = .(x, y);

		//String timeStr = Utils.TimeToStr(GetTimeAt(x), .. scope .());

		//Debug.WriteLine($"Time: {GetTimeAt(x)} {timeStr}");
	}

	public override void MouseClicked(float x, float y, float origX, float origY, int32 btn)
	{
		base.MouseClicked(x, y, origX, origY, btn);
	}

	public void Clamp()
	{
		double minScale = (mWidth / ((double)gApp.mSigData.TickCount)) * 0.5f;
		mScale = Math.Clamp(mScale, minScale, 400);
		mTickOfs = Math.Clamp(mTickOfs, 0, Math.Max(0, (gApp.mSigData.TickCount + TrailingTicks) - mWidth / mScale));
	}

	public override void MouseMove(float x, float y)
	{
		base.MouseMove(x, y);

		if ((mMouseDown) && (!mWidgetWindow.IsKeyDown(.Control)))
		{
			float deltaX = x - mMouseDownX;
			//float deltaY = y - mMouseDownY;
			mTickOfs -= deltaX / mScale;

			Clamp();

			mHorzScrollbar.ScrollTo(mTickOfs);
			//mVertScrollbar.ScrollTo(mVertScrollbar.mContentPos - deltaY);

			mMouseDownX = x;
			mMouseDownY = y;
		}
		mMousePos = .(x, y);
	}

	public override void MouseLeave()
	{
		base.MouseLeave();
		mMousePos = null;
	}

	public override void Resize(float x, float y, float width, float height)
	{
		base.Resize(x, y, width, height);
		mHorzScrollbar.Resize(-GS!(1), mHeight - GS!(18), mWidth - GS!(14), GS!(18));
		mVertScrollbar.Resize(mWidth - GS!(18), -GS!(1), GS!(20), mHeight - GS!(14));
		UpdateScrollbar();
	}

	public void UpdateScrollbar()
	{
		if (gApp.mSigData == null)
			return;

		mHorzScrollbar.mPageSize = mWidth / mScale;
		mHorzScrollbar.mContentSize = gApp.mSigData.TickCount + TrailingTicks;
		mHorzScrollbar.ScrollTo(mTickOfs);
		mHorzScrollbar.UpdateData();

		var listView = gApp.mSigPanel.mSigActiveListPanel.mListView;
		mVertScrollbar.mPageSize = listView.mScrollContentContainer.mHeight;
		mVertScrollbar.mContentSize = listView.mScrollContent.mHeight;
		mVertScrollbar.UpdateData();
	}

	public override void Update()
	{
		base.Update();

		if ((mWidgetWindow.IsKeyDown(.Control)) && (mMousePos != null) && (mMouseDown))
		{
			mCursorTick = GetTickAt(mMousePos.Value.x);
			gApp.mSigPanel.UpdateValues();
		}

		UpdateScrollbar();
	}
}
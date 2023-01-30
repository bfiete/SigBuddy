using System;
using Beefy.gfx;
using Beefy.widgets;
using Beefy.theme.dark;
using Beefy.theme;
using System.Diagnostics;
using Beefy.geom;
using System.Collections;

namespace SigBuddy.ui;

class SigViewPanel : Panel
{
	public DarkScrollbar mHorzScrollbar;
	public DarkScrollbar mVertScrollbar;
	public double mScale = 1.0f;
	public double mDestTickOfs = 0;
	public double mDrawTickOfs = 0;
	public double? mCursorTick;

	public int32 mDrawIdx;
	public Point? mMousePos;
	public float mMouseDownX;
	public float mMouseDownY;
	public int32 mTimeResDigits;
	public bool mIgnoreScroll;

	public SigPanel.Entry mLastFindEntry;
	public List<uint32> mLastFindData ~ delete _;
	public double? mDeferVertPos;

	public this()
	{
		mClipGfx = true;
		mHorzScrollbar = (.)ThemeFactory.mDefault.CreateScrollbar(Scrollbar.Orientation.Horz);
		mVertScrollbar = (.)ThemeFactory.mDefault.CreateScrollbar(Scrollbar.Orientation.Vert);

		AddWidget(mHorzScrollbar);
		AddWidget(mVertScrollbar);

		mHorzScrollbar.mOnScrollEvent.Add(new (evt) =>
			{
				if (!mIgnoreScroll)
				{
					mDestTickOfs = evt.mNewPos;
					SnapDrawPositions();
				}
			});
		mVertScrollbar.mOnScrollEvent.Add(new (evt) =>
			{
				if (!mIgnoreScroll)
				{
					//gApp.mSigPanel.mSigActiveListPanel.mListView.UpdateContentPosition();
					var scrollContent = gApp.mSigPanel.mSigActiveListPanel.mListView.mScrollContent;
					scrollContent.Resize(
						0,
						//(int32)(-mVertPos.v - (mVertScrollbar?.mContentStart).GetValueOrDefault()),
						(.)-evt.mNewPos,
						scrollContent.mWidth, scrollContent.mHeight);
				}
			});

		UpdateScrollbar();
		mAutoFocus = true;
	}

	public double? CursorTick
	{
		get
		{
			return mCursorTick;
		}

		set
		{
			mCursorTick = value;
			gApp.mSigPanel.mValuesDirty = true;
		}
	}

	//public int TrailingTicks = Math.Min(gApp.mSigData.TickCount / 10, 100);
	//public int TrailingTicks = (.)(100 * mScale);
	public int TrailingTicks => (.)(100 / mScale);

	public float GetTickX(int64 tick)
	{
		return (.)((tick - gApp.mSigData.mStartTick - mDrawTickOfs) * mScale);
	}

	public float GetTickX(double tick)
	{
		return (.)((tick - gApp.mSigData.mStartTick - mDrawTickOfs) * mScale);
	}

	public float GetTimeX(double time)
	{
		double tick = time / gApp.mSigData.mTimescale;
		return (.)((tick - gApp.mSigData.mStartTick - mDrawTickOfs) * mScale);
	}

	public double GetTickAt(float x)
	{
		return x / mScale + gApp.mSigData.mStartTick + mDrawTickOfs;
	}

	public double GetTimeAt(float x)
	{
		return (x / mScale + gApp.mSigData.mStartTick + mDrawTickOfs) * gApp.mSigData.mTimescale;
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
		}

		double zeroTime = GetTimeAt(0);

		String timeStr = scope .();

		float lastDrawX = 0;

		int i = (.)(zeroTime / sectionScale);
		float sectionWidth = GetTimeX(sectionScale * (i + 1)) - GetTimeX(sectionScale * i);
		float maxStrWidth = 0;
		mTimeResDigits = (.)Math.Log10(i);

		while (true)
		{
			double time = i * sectionScale;
			float x = GetTimeX(time);
			if (x > mWidth)
			{
				break;
			}
			i++;
			timeStr.Clear();
			SigUtils.TimeToStr(time, timeStr, mTimeResDigits);
			maxStrWidth = Math.Max(maxStrWidth, g.mFont.GetWidth(timeStr));
		}

		bool skipOdd = maxStrWidth + 8 > sectionWidth;

		i = (.)(zeroTime / sectionScale);
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
				SigUtils.TimeToStr(time, timeStr, mTimeResDigits);
				var strWidth = g.mFont.GetWidth(timeStr);

				if ((!skipOdd) || (i % 2 == 0))
				{
					g.DrawString(timeStr, x - strWidth/2, 5);
					lastDrawX = x;
				}
			}

			i++;
		}
	}

	public void DrawSignals(Graphics g)
	{
		/*if (mDrawIdx == 1)
		{
			if (Profiler.StartSampling() case .Ok(var val))
				defer:: val.Dispose();
		}*/

		uint32[2][4096] decodedDataBuf = ?;

		int minDrawTick = (.)GetTickAt(-4);

		int lodTickTarget = (.)(0.95f / mScale);
		int lodSelector = 0;

		while ((1<<(lodSelector + 1) <= lodTickTarget) && (lodSelector < SignalChunk.cMaxLODSelector))
			lodSelector++;

		bool isDebug = mWidgetWindow.IsKeyDown(.Tilde);
		if ((isDebug) && (mUpdateCnt % 60 == 0))
			Debug.WriteLine($"LODTickTarget: {lodTickTarget} LODScale:{lodSelector} ({1<<lodSelector})");


		void DrawSignal(SigPanel.Entry entry)
		{
			if (entry.mY == null)
				return;

			uint32 color = entry.mColor;

			//float curX = 0;
			//float curY = @entry.Index * 20 + 20;
			float curY = entry.mY.Value;

			/*using (g.PushColor(0xFF00FF00))
			{
				g.FillRect(curX, curY, 50, 18);
			}*/

			bool drewSigBar = false;
			bool drewZero = false;
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
				bool lastWasZero = drewZero;
				drewZero = false;

				int64 ix = (int64)(x + 1000) - 1000;
				int64 iEndX = (int64)(endX + 1000) - 1000;

				float drawX = ix;
				//float drawWidth = (int64)endX - (int64)x;
				float drawWidth = iEndX - ix;

				if (drawWidth < 2)
					drawWidth = 2;

				float drawEndX = drawX + drawWidth;
				if (drawEndX < -4)
					return;

				float endXDelta = drawEndX - lastDrawEndX;

				if (endXDelta < 2.0f)
				{
					if (endXDelta >= 0.0f)
					{
						using (g.PushColor(color))
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
					drawWidth = iEndX - (int64)drawX;
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
							lastDrawEndX = drawX + 2;
						}
						else
						{
							if (lastWasBar)
							{
								drawX = origLastDrawEndX;
								drawWidth = iEndX - (int64)drawX;
							}

							SigUIImage imageKind = useAngled ? .SigFullAngled : .SigFull;
							if ((useAngled) && (drawWidth < 7))
								imageKind = .SigFullAngledShort;

							g.DrawButton(gApp.mSigUIImages[(.)imageKind], drawX, curY, drawWidth);
						}
					}
					else
					{
						if (lastWasZero)
						{
							g.Draw(gApp.mSigBar, drawX, curY);
							origLastDrawEndX = drawX + 3;
							lastWasBar = true;
						}

						if (lastWasBar)
						{
							drawX = origLastDrawEndX;
							drawWidth = iEndX - (int64)drawX;
						}

						if (drawWidth < 6.0f)
							useAngled = false;

						g.DrawButton(gApp.mSigUIImages[useAngled ? (.)SigUIImage.SigEmptyAngled :
							(.)SigUIImage.SigEmpty], drawX, curY, drawWidth);

						drewZero = true;
					}
				}

				if ((signalData.mNumBits > 1) || (hasUndefined))
				{
					if (drawX < 0)
					{
						float adjust = -drawX - 3;

						drawWidth -= adjust;
						drawX += adjust;
					}

					if (drawWidth > 20)
					{
						String drawStr = scope .(64);
						entry.GetValueString(decodedData, drawStr, false);
						g.DrawString(drawStr, drawX + 5, curY + 5, .Left, drawWidth - 8, .Ellipsis);
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

				//TODO: Remove debug keys
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
					while (lodSelector >= chunk.mLODIndices.Count)
					{
						chunk.GenerateNextLOD();
					}
					lodIdx = chunk.mLODIndices[lodSelector];
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

				if (isDebug)
				{
					if (lodIdx == -1)
						color = 0xFF00FF00;
					else if (lodIdx == 0)
						color = 0xFFFF0000;
					else if (lodIdx == 1)
						color = 0xFF0000FF;
					else
						color = 0xFFFFFF00;
				}

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

				if (isDebug)
				{
					g.FillRect(prevSigX, curY - 2, 1, 20 + 4);
					//break;
				}
			}

			if (decodeIdx > 0)
			{
				uint32* prevDecodedData = &decodedDataBuf[(decodeIdx % 2) ^ 1];
				float sigX = GetTickX(gApp.mSigData.mEndTick);
				if (prevSigX < mWidth)
					Draw(prevSigX, sigX, prevDecodedData);
			}
		}

		void DrawEntry(SigPanel.Entry entry)
		{
			if (entry.mSignal != null)
				DrawSignal(entry);

			if (entry.mChildren != null)
			{
				for (var child in entry.mChildren)
				{
					DrawEntry(child);
				}
			}
		}

		for (var entry in gApp.mSigPanel.mEntries)
		{
			DrawEntry(entry);
		}
	}

	public override void Draw(Graphics g)
	{
		mDrawIdx++;

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

		mDestTickOfs = (xTick - gApp.mSigData.mStartTick) + -centerX / mScale;

		if (mDestTickOfs < 0)
			mDestTickOfs = 0;

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
		mDestTickOfs = Math.Clamp(mDestTickOfs, 0, Math.Max(0, (gApp.mSigData.TickCount + TrailingTicks) - mWidth / mScale));
	}

	public override void MouseMove(float x, float y)
	{
		base.MouseMove(x, y);

		if ((mMouseDown) && (!mWidgetWindow.IsKeyDown(.Control)))
		{
			float deltaX = x - mMouseDownX;
			//float deltaY = y - mMouseDownY;
			mDestTickOfs -= deltaX / mScale;

			Clamp();

			//mHorzScrollbar.ScrollTo(mDestTickOfs);
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

		mIgnoreScroll = true;

		mHorzScrollbar.mPageSize = mWidth / mScale;
		mHorzScrollbar.mContentSize = gApp.mSigData.TickCount + TrailingTicks;
		mHorzScrollbar.ScrollTo(mDrawTickOfs);
		mHorzScrollbar.UpdateData();

		var listView = gApp.mSigPanel.mSigActiveListPanel.mListView;
		mVertScrollbar.mPageSize = listView.mScrollContentContainer.mHeight;
		mVertScrollbar.mContentSize = listView.mScrollContent.mHeight;
		mVertScrollbar.UpdateData();

		mIgnoreScroll = false;
	}

	public override void Update()
	{
		base.Update();

		if ((mWidgetWindow.IsKeyDown(.Control)) && (mMousePos != null) && (mMouseDown))
		{
			CursorTick = GetTickAt(mMousePos.Value.x);
		}

		/*if (Math.Abs(mDestTickOfs - mDrawTickOfs) < 1.5/mScale)
		{
			mDrawTickOfs = mDestTickOfs;
		}
		else
		{
			double ofs = (mDestTickOfs - mDrawTickOfs + Math.Sign(mDestTickOfs - mDrawTickOfs)*10.0f/mScale) * 0.04;
			mDrawTickOfs += ofs;
		}*/

		mDrawTickOfs = mDestTickOfs;

		UpdateScrollbar();

		if (mDeferVertPos != null)
		{
			mVertScrollbar.ScrollTo(mDeferVertPos.Value);
			mDeferVertPos = null;
		}
	}

	public void EnsureCursorVisible()
	{
		if (mCursorTick == null)
			return;

		if (mCursorTick.Value < mDestTickOfs)
			mDestTickOfs = mCursorTick.Value - (mWidth * 0.075f)/mScale;

		if (mCursorTick.Value >= mDestTickOfs + (mWidth * 0.95) / mScale)
			mDestTickOfs = mCursorTick.Value - (mWidth * 0.6f)/mScale;

		Clamp();
	}

	public void SnapDrawPositions()
	{
		mDrawTickOfs = mDestTickOfs;
	}

	public void FindNext()
	{
		if (mLastFindEntry == null)
			return;

		int64 startTick = 0;
		if (mCursorTick != null)
			startTick = (.)mCursorTick.Value + 1;
		
		switch (mLastFindEntry.FindValue(mLastFindData.Ptr, startTick))
		{
		case .Ok(let val):
			CursorTick = val;
			EnsureCursorVisible();
		case .Err(let err):
			gApp.Fail("End of timeline reached without finding value");
			CursorTick = null;
		}
	}
	
	public void FindPrev()
	{
		if (mLastFindEntry == null)
			return;

		int64 endTick = gApp.mSigData.mEndTick;
		if (mCursorTick != null)
			endTick = (.)mCursorTick.Value;

		switch (mLastFindEntry.FindValueBefore(mLastFindData.Ptr, endTick))
		{
		case .Ok(let val):
			CursorTick = val;
			EnsureCursorVisible();
		case .Err(let err):
			gApp.Fail("Start of timeline reached without finding value");
			CursorTick = null;
		}
	}

	public override void KeyDown(KeyCode keyCode, bool isRepeat)
	{
		if (mWidgetWindow.GetKeyFlags() == .None)
		{
			switch (keyCode)
			{
			case (.)'T':
				var tickStr = ((int64)mCursorTick.GetValueOrDefault()).ToString(.. scope .());
				gApp.SetClipboardText(tickStr);
			case .Left, .Right:
				var lvi = (SigActiveListViewItem)gApp.mSigPanel.mSigActiveListPanel.mListView.GetRoot().FindFocusedItem();
				if (lvi != null)
				{
					if (mCursorTick == null)
					{
						CursorTick = 0;
						EnsureCursorVisible();
					}
					else
					{
						var entry = lvi.mEntry;
						(var prevIdx, var nextIdx) = entry.FindEdges((.)mCursorTick.Value);
						if (keyCode == .Left)
						{
							if (prevIdx != -1)
							{
								CursorTick = prevIdx;
								EnsureCursorVisible();
							}
						}
						else 
						{
							if (nextIdx != -1)
							{
								CursorTick = nextIdx;
								EnsureCursorVisible();
							}
						}
					}
				}
			case .Home:
				CursorTick = gApp.mSigData.mStartTick;
				EnsureCursorVisible();
			case .End:
				CursorTick = gApp.mSigData.mEndTick;
				EnsureCursorVisible();
			case .PageUp:
				CursorTick = Math.Max(mCursorTick.GetValueOrDefault() - mWidth * 0.9 / mScale, gApp.mSigData.mStartTick);
				EnsureCursorVisible();
			case .PageDown:
				CursorTick = Math.Min(mCursorTick.GetValueOrDefault() + mWidth * 0.9 / mScale, gApp.mSigData.mEndTick);
				EnsureCursorVisible();
			case .Delete:
				var dialog = ThemeFactory.mDefault.CreateDialog("Delete?", 
					"Are you sure you want to delete entry?",
					DarkTheme.sDarkTheme.mIconWarning);
				dialog.mDefaultButton = dialog.AddButton("Yes", new (evt) =>
					{
						gApp.mSigPanel.mSigActiveListPanel.DoDelete();
					});
				dialog.mEscButton = dialog.AddButton("No", new (evt) =>
					{
						dialog.Close();
					});
				dialog.PopupWindow(mWidgetWindow);
			default:
			}
		}
		else if (mWidgetWindow.GetKeyFlags() == .Ctrl)
		{
			switch (keyCode)
			{
			case (.)'R':
				gApp.mSigPanel.mSigActiveListPanel.DoRename();
			default:
			}
		}
	}
}
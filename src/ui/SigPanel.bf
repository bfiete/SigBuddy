using Beefy.gfx;
using Beefy.widgets;
using Beefy.theme.dark;
using System.Collections;
using System;

namespace SigBuddy.ui;

class SigPanel : DockedWidget
{
	public class Splitter : Widget
	{
		public float mDownX;

		public override void Draw(Graphics g)
		{
			/*using (g.PushColor(0x8000FF00))
				g.FillRect(0, 0, mWidth, mHeight);*/
		}

		public override void MouseEnter()
		{
			base.MouseEnter();
			gApp.SetCursor(.SizeWE);
		}

		public override void MouseLeave()
		{
			base.MouseLeave();
			gApp.SetCursor(.Pointer);
		}

		public override void MouseDown(float x, float y, int32 btn, int32 btnCount)
		{
			base.MouseDown(x, y, btn, btnCount);
			//CaptureMouse();
			mDownX = x;
		}

		public override void MouseUp(float x, float y, int32 btn)
		{
			base.MouseUp(x, y, btn);
		}

		public override void MouseMove(float x, float y)
		{
			base.MouseMove(x, y);

			if (mMouseDown)
			{
				var sigPanel = mParent as SigPanel;

				float delta = x - mDownX;
				sigPanel.mWantListWidth = Math.Max(sigPanel.mWantListWidth + delta, 48);
				sigPanel.ResizeComponents();
			}
		}
	}

	public class Entry
	{
		public Entry mParent;
		public List<Entry> mChildren ~ DeleteContainerAndItems!(_);

		public Signal mSignal;
		public String mName ~ delete _;

		public SigUtils.DataFormat mDataFormat = .Auto;
		public bool mReverseBits;
		public bool mInvertBits;
		public bool mRightJustify;
		public bool mPopCount;
		public bool mAwaitingRename;
		public uint32 mColor = 0xFF00FF00;
		public uint32 mColorUndef;
		public float? mY;
		public List<Entry> ParentList => (mParent == null) ? gApp.mSigPanel.mEntries : mParent.mChildren;

		public this()
		{

		}

		public SigUtils.DataFormat DataFormat
		{
			get
			{
				if (mDataFormat == .Auto)
					return (mSignal.mSignalData.mNumBits >= 8) ? .Hex : .Binary;
				return mDataFormat;
			}
		}

		public void GetValueString(uint32* decodedData, String outStr, bool addPrefix)
		{
			var signalData = mSignal.mSignalData;

			void AddPrefix(char8 c)
			{
				outStr.Append(Font.EncodeColor(0xFF909090));
				outStr.Append(c);
				outStr.Append(Font.EncodePopColor());
			}

			var dataFormat = DataFormat;

			if (signalData.mStrings != null)
			{

				uint64 val = 0;
				bool hasX = false;
				bool hasZ = false;

				for (int bit < signalData.mNumBits)
				{
					uint8 bVal = (.)(decodedData[bit / 16] >> ((bit % 16) * 2)) & 3;
					if (bVal == 2)
						hasX = true;
					else if (bVal == 3)
						hasZ = true;
					val += (uint64)bVal << bit;
				}

				if (val < (.)signalData.mStrings.Count)
				{
					var str = signalData.mStrings[(.)val];
					if (str != null)
					{
						outStr.Append(str);
						return;
					}
				}
				dataFormat = .Decimal;
			}

			switch (dataFormat)
			{
			case .Binary:
				if (addPrefix)
					AddPrefix('b');
				for (int bit in (0..<signalData.mNumBits).Reversed)
				{
					uint8 bVal = (.)(decodedData[bit / 16] >> ((bit % 16) * 2)) & 3;
					outStr.Append(SigUtils.sBinaryChars[bVal]);
				}
			case .Hex:
				if (addPrefix)
					AddPrefix('h');
				for (int nibble = (signalData.mNumBits + 3)/4 - 1; nibble >= 0; nibble--)
				{
					uint8 nVal = (.)(decodedData[nibble / 4] >> ((nibble % 4) * 8)) & 0xFF;
					outStr.Append(SigUtils.sHexChars[nVal]);
				} 
			case .Octal:
				if (addPrefix)
					AddPrefix('o');
				int numDigits = (signalData.mNumBits + 2) / 3;
				for (int digitNum = numDigits - 1; digitNum >= 0; digitNum--)
				{
					int bit = digitNum * 3;
					int oVal = (((decodedData[(bit) / 16] >> (((bit) % 16) * 2)) & 3) << 0) |
						(((decodedData[(bit + 1) / 16] >> (((bit + 1) % 16) * 2)) & 3) << 2) |
						(((decodedData[(bit + 2) / 16] >> (((bit + 2) % 16) * 2)) & 3) << 4);
					outStr.Append(SigUtils.sOctalChars[oVal]);
				}
			case .Decimal, .DecimalSigned:
				if (addPrefix)
					AddPrefix('d');
				uint64 val = 0;
				bool hasX = false;
				bool hasZ = false;

				for (int bit < signalData.mNumBits)
				{
					uint8 bVal = (.)(decodedData[bit / 16] >> ((bit % 16) * 2)) & 3;
					if (bVal == 2)
						hasX = true;
					else if (bVal == 3)
						hasZ = true;
					val += (uint64)bVal << bit;
				}
				if (hasX)
					outStr.Append("XXX");
				else if (hasZ)
					outStr.Append("ZZZ");
				else
				{
					if (dataFormat == .DecimalSigned)
					{
						int64 iVal = (int64)val;
						if ((val & (1 << signalData.mNumBits)) != 0)
						{
							iVal = -(iVal & ((1 << signalData.mNumBits) - 1)) - 1;
						}
						iVal.ToString(outStr);
					}
					else
						val.ToString(outStr);
				}
			default:
			}
		}

		public void GetValueStringAtTick(double valueTick, String outStr)
		{
			if (mSignal == null)
				return;

			uint32[2][4096] decodedDataBuf = ?;
			var signalData = mSignal.mSignalData;
			int decodeIdx = 0;

			uint32* decodedData = null;
			uint32* prevDecodedData = null;

			for (var chunk in signalData.mChunks)
			{
				if (valueTick > chunk.mEndTick)
					continue;

				int64 curTick = chunk.mStartTick;

				var chunkData = chunk.mRawData;

				uint8* chunkPtr = chunkData.mBuffer.Ptr;
				uint8* chunkEndPtr = chunkPtr + chunkData.mBuffer.Count;
				while (chunkPtr < chunkEndPtr)
				{
					decodedData = &decodedDataBuf[decodeIdx % 2];
					prevDecodedData = &decodedDataBuf[(decodeIdx % 2) ^ 1];

					// Zero out trailing fill bits in the last signal word 
					decodedData[signalData.mNumBits/16] = 0;

					chunkData.Decode(ref chunkPtr, decodedData, var tickDelta);
					curTick += tickDelta;

					if (curTick > valueTick)
					{
						GetValueString(prevDecodedData, outStr, true);
						return;
					}

					decodeIdx++;
				}
			}

			if (decodedData != null)
				GetValueString(decodedData, outStr, true);
		}

		public Result<int64> FindValue(uint32* value, int64 startTick)
		{
			uint32[2][4096] decodedDataBuf = ?;
			var signalData = mSignal.mSignalData;
			int decodeIdx = 0;

			uint32* prevDecodedData = null;

			for (var chunk in signalData.mChunks)
			{
				if (startTick > chunk.mEndTick)
					continue;

				int64 curTick = chunk.mStartTick;

				var chunkData = chunk.mRawData;

				uint8* chunkPtr = chunkData.mBuffer.Ptr;
				uint8* chunkEndPtr = chunkPtr + chunkData.mBuffer.Count;
				while (chunkPtr < chunkEndPtr)
				{
					uint32* decodedData = &decodedDataBuf[decodeIdx % 2];
					prevDecodedData = &decodedDataBuf[(decodeIdx % 2) ^ 1];

					// Zero out trailing fill bits in the last signal word 
					decodedData[signalData.mNumBits/16] = 0;

					chunkData.Decode(ref chunkPtr, decodedData, var tickDelta);
					curTick += tickDelta;

					if (curTick >= startTick)
					{
						if (value[0] == decodedData[0])
						{
							bool matches = true;
							if (chunkData.mNumBits > 16)
							{
								for (int checkIdx < (chunkData.mNumBits + 15) / 16)
									matches &= value[checkIdx] == decodedData[checkIdx];
							}

							if (matches)
								return .Ok(curTick);
						}
					}

					decodeIdx++;
				}
			}

			return .Err;
		}

		public Result<int64> FindValueBefore(uint32* value, int64 endTick)
		{
			uint32[2][4096] decodedDataBuf = ?;
			var signalData = mSignal.mSignalData;
			int decodeIdx = 0;

			uint32* prevDecodedData = null;

			int64 foundTick = -1;

			for (var chunk in signalData.mChunks)
			{
				int64 curTick = chunk.mStartTick;

				var chunkData = chunk.mRawData;

				uint8* chunkPtr = chunkData.mBuffer.Ptr;
				uint8* chunkEndPtr = chunkPtr + chunkData.mBuffer.Count;
				while (chunkPtr < chunkEndPtr)
				{
					uint32* decodedData = &decodedDataBuf[decodeIdx % 2];
					prevDecodedData = &decodedDataBuf[(decodeIdx % 2) ^ 1];

					// Zero out trailing fill bits in the last signal word 
					decodedData[signalData.mNumBits/16] = 0;

					chunkData.Decode(ref chunkPtr, decodedData, var tickDelta);
					curTick += tickDelta;

					if (curTick >= endTick)
					{
						if (foundTick != -1)
							return .Ok(foundTick);
						return .Err;
					}

					if (value[0] == decodedData[0])
					{
						bool matches = true;
						if (chunkData.mNumBits > 16)
						{
							for (int checkIdx < (chunkData.mNumBits + 15) / 16)
								matches &= value[checkIdx] == decodedData[checkIdx];
						}

						if (matches)
							foundTick = curTick;
					}

					decodeIdx++;
				}
			}

			if (foundTick != -1)
				return .Ok(foundTick);
			return .Err;
		}

		public (int64 prev, int64 next) FindEdges(int64 startTick)
		{
			uint32[4096] decodedData = ?;
			var signalData = mSignal.mSignalData;
			int decodeIdx = 0;

			int64 prevTick = -1;

			prevTick = gApp.mSigData.mStartTick;

			for (var chunk in signalData.mChunks)
			{
				if (startTick > chunk.mEndTick)
				{
					prevTick = chunk.mEndTick;
					continue;
				}

				int64 curTick = chunk.mStartTick;

				var chunkData = chunk.mRawData;

				uint8* chunkPtr = chunkData.mBuffer.Ptr;
				uint8* chunkEndPtr = chunkPtr + chunkData.mBuffer.Count;
				while (chunkPtr < chunkEndPtr)
				{
					// Zero out trailing fill bits in the last signal word 
					decodedData[signalData.mNumBits/16] = 0;

					chunkData.Decode(ref chunkPtr, &decodedData, var tickDelta);
					curTick += tickDelta;

					if (curTick < startTick)
						prevTick = curTick;
					if (curTick > startTick)
					{
						return (prevTick, curTick);
					}

					decodeIdx++;
				}
			}

			return (prevTick, -1);
		}
	}

	public Splitter mSplitter;
	public SigActiveListPanel mSigActiveListPanel;
	public SigViewPanel mSigViewPanel;
	public float mWantListWidth;
	public List<Entry> mEntries = new .() ~ DeleteContainerAndItems!(_);
	public bool mValuesDirty;
	public bool mEntryListViewDirty;

	public this()
	{
		mSigActiveListPanel = new SigActiveListPanel();
		mSigActiveListPanel.mSigPanel = this;
		mSigViewPanel = new SigViewPanel();
		mSplitter = new Splitter();

		AddWidget(mSigActiveListPanel);
		AddWidget(mSigViewPanel);
		AddWidget(mSplitter);

		mWantListWidth = 280;
	}

	public override void Draw(Graphics g)
	{
		/*using (g.PushColor(0xFF00FF00))
			g.FillRect(0, 0, mWidth, mHeight);*/
	}

	public void WithEntries(delegate void (Entry entry) dlg)
	{
		void Handle(List<Entry> entryList)
		{
			for (var entry in entryList)
			{
				dlg(entry);
				if (entry.mChildren != null)
					Handle(entry.mChildren);
			}
		}
		Handle(mEntries);
	}

	public override void DrawAll(Graphics g)
	{
		base.DrawAll(g);

		float ofsY = (.)mSigViewPanel.mVertScrollbar.mContentPos;

		using (g.PushClip(0, GS!(20), mWidth - GS!(16), mHeight - GS!(20)))
		{
			float ofs = (.)mSigViewPanel.mVertScrollbar.mContentPos;

			int idx = 0;
			WithEntries(scope [&] (entry) =>
				{
					/*uint32 color = 0;
					if (@entry.Index % 2 == 0)
						color = 0x08FFFFFF;
	
					if (mSigViewPanel.mMousePos != null)
					{
						if ((mSigViewPanel.mMousePos.Value.y >= entry.mY) &&
							(mSigViewPanel.mMousePos.Value.y < entry.mY + GS!(20)))
							color = 0x18FFFFFF;
					}*/

					if (entry.mY == null)
						return;

					var entryY = entry.mY.Value;

					uint32 color = 0;
					if (idx % 2 == 0)
					{
						Color.ToHSV(entry.mColor, var h, var s, var v);
						s *= 0.3f;
						color = Color.FromHSV(h, s, v, 0x10);
					}
					else
					{
						Color.ToHSV(entry.mColor, var h, var s, var v);
						s *= 0.3f;
						color = Color.FromHSV(h, s, v, 0x08);
					}

					if (mSigViewPanel.mMousePos != null)
					{
						if ((mSigViewPanel.mMousePos.Value.y + ofsY >= entry.mY) &&
							(mSigViewPanel.mMousePos.Value.y + ofsY < entry.mY + GS!(20)))
						{
							//color = 0x18FFFFFF;
							Color.ToHSV(entry.mColor, var h, var s, var v);
							s *= 0.2f;
							color = Color.FromHSV(h, s, v, 0x1B);
						}
					}
	
					if (color != 0)
					{
						using (g.PushColor(color))
						{
							g.FillRect(0, entryY - ofs, mWidth, GS!(20));
						}
					}

					if (entry.mSignal == null)
					{
						Color.ToHSV(entry.mColor, var h, var s, var v);
						s *= 0.7f;
						color = Color.FromHSV(h, s, v, 0x38);
						using (g.PushColor(color))
						{
							float x = mSigActiveListPanel.mWidth;
							g.FillRect(x, entryY - ofs, mWidth - x, GS!(20));
						}
					}

					idx++;
				});
		}
	}

	public override void Resize(float x, float y, float width, float height)
	{
		base.Resize(x, y, width, height);
		ResizeComponents();
	}

	public void ResizeComponents()
	{
		mSigActiveListPanel.Resize(0, 0, mWantListWidth, mHeight);
		float x = mWantListWidth + GS!(2);
		mSigViewPanel.Resize(x, 0, Math.Max(mWidth - x, 32), mHeight);

		mSplitter.Resize(mWantListWidth - 3, 0, 6, mHeight);
	}

	public override void MouseMove(float x, float y)
	{
		base.MouseMove(x, y);
	}

	public void Rebuild()
	{
		mSigViewPanel.UpdateScrollbar();
	}

	public void UpdateValues()
	{
		var valueStr = scope String();
		mSigActiveListPanel.mListView.GetRoot().WithItems(scope (lvi) =>
			{
				valueStr.Clear();
				var listViewItem = (SigActiveListViewItem)lvi;
				var subListViewItem = (SigActiveListViewItem)listViewItem.GetSubItem(1);
	
				if (mSigViewPanel.mCursorTick != null)
				{
					listViewItem.mEntry.GetValueStringAtTick(mSigViewPanel.mCursorTick.Value, valueStr);
				}
	
				subListViewItem.Label = valueStr;
			});
	}

	public override void Update()
	{
		base.Update();

		if (mEntryListViewDirty)
		{
			mSigActiveListPanel.RebuildListView();
			mEntryListViewDirty = false;
			mValuesDirty = true;
		}

		if (mValuesDirty)
		{
			UpdateValues();
			mValuesDirty = false;
		}
	}

	public Entry CreateEntry()
	{
		SigActiveListViewItem parentLVI = (.)mSigActiveListPanel.mListView.GetRoot();
		Entry parent = null;
		int insertIdx = mEntries.Count;

		var activeListView = mSigActiveListPanel.mListView;
		activeListView.GetRoot().WithItems(scope [&] (lvi) =>
			{
				if (lvi.Focused)
				{
					var activeLVI = (SigActiveListViewItem)lvi;
					parent = activeLVI.mEntry.mParent;
					if (parent == null)
						insertIdx = mEntries.IndexOf(activeLVI.mEntry);
					else
						insertIdx = parent.mChildren.IndexOf(activeLVI.mEntry);
					parentLVI = (.)activeLVI.mParentItem;
				}
			});

		var entry = new SigPanel.Entry();
		if (parent == null)
			mEntries.Insert(insertIdx, entry);
		else
			parent.mChildren.Insert(insertIdx, entry);
		entry.mParent = parent;

		mEntryListViewDirty = true;

		return entry;
	}
}
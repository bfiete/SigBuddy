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

	[Reflect]
	public enum DataFormat
	{
		Auto,
		Binary,
		Hex,
		Decimal,
		DecimalSigned,
		Octal,
		Ascii,
	}

	public class Entry
	{
		public Signal mSignal;

		public DataFormat mDataFormat = .Auto;
		public bool mReverseBits;
		public bool mInvertBits;
		public bool mRightJustify;
		public bool mPopCount;
		public uint32 mColor = 0xFF00FF00;
		public uint32 mColorUndef;
		public float mY;

		public DataFormat DataFormat
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
			switch (dataFormat)
			{
			case .Binary:
				if (addPrefix)
					AddPrefix('b');
				for (int bit in (0..<signalData.mNumBits).Reversed)
				{
					uint8 bVal = (.)(decodedData[bit / 16] >> ((bit % 16) * 2)) & 3;
					outStr.Append(Utils.sBinaryChars[bVal]);
				}
			case .Hex:
				if (addPrefix)
					AddPrefix('h');
				for (int nibble = (signalData.mNumBits + 3)/4 - 1; nibble >= 0; nibble--)
				{
					uint8 nVal = (.)(decodedData[nibble / 4] >> ((nibble % 4) * 8)) & 0xFF;
					outStr.Append(Utils.sHexChars[nVal]);
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
					outStr.Append(Utils.sOctalChars[oVal]);
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
			uint32[2][4096] decodedDataBuf = ?;
			var signalData = mSignal.mSignalData;
			int decodeIdx = 0;

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
					uint32* decodedData = &decodedDataBuf[decodeIdx % 2];
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

			if (prevDecodedData != null)
				GetValueString(prevDecodedData, outStr, true);
		}
	}

	public Splitter mSplitter;
	public SigActiveListPanel mSigActiveListPanel;
	public SigViewPanel mSigViewPanel;
	public float mWantListWidth;
	public List<Entry> mEntries = new .() ~ DeleteContainerAndItems!(_);

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
		var root = mSigActiveListPanel.mListView.GetRoot();

		var valueStr = scope String();

		for (int itemIdx < root.GetChildCount())
		{
			valueStr.Clear();
			var listViewItem = (SigActiveListViewItem)root.GetChildAtIndex(itemIdx);
			var subListViewItem = (SigActiveListViewItem)listViewItem.GetSubItem(1);

			if (mSigViewPanel.mCursorTick != null)
			{
				listViewItem.mEntry.GetValueStringAtTick(mSigViewPanel.mCursorTick.Value, valueStr);
			}

			subListViewItem.Label = valueStr;
		}
	}
}
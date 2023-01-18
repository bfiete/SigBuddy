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

	public enum DataFormat
	{
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

		public DataFormat mDataFormat = .Binary;
		public bool mReverseBits;
		public bool mInvertBits;
		public bool mRightJustify;
		public bool mPopCount;
		public uint32 mColor = 0xFF00FF00;
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
		float x = mWantListWidth + GS!(6);
		mSigViewPanel.Resize(x, 0, mWidth - x, mHeight);

		mSplitter.Resize(mWantListWidth - 3, 0, 6, mHeight);
	}

	public override void MouseMove(float x, float y)
	{
		base.MouseMove(x, y);
	}
}
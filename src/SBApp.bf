using System;
using Beefy;
using Beefy.theme.dark;
using Beefy.theme;
using Beefy.gfx;
using Beefy.widgets;
using Beefy.sys;
using SigBuddy.ui;

namespace SigBuddy;

enum SigUIImage
{
	SigEmpty,
	SigFull,
	SigEmptyAngled,
	SigFullAngled,
	SigFullAngledShort,
	SigBar,
	COUNT
}

class SBApp : BFApp
{
	public Font mSmFont ~ delete _;
	public WidgetWindow mMainWindow;

	public MainFrame mMainFrame;
	public DarkDockingFrame mDockingFrame;

	public Image mSigUIImage ~ delete _;
	public Image[] mSigUIImages ~ delete _;
	public Image mSigBar ~ delete _;

	public SigPanel mSigPanel;
	public SigGroupPanel mSigGroupPanel;
	public SigListPanel mSigListPanel;
	public SigData mSigData ~ delete _;

	public this()
	{
		gApp = this;
	}

	public ~this()
	{
		for (var image in mSigUIImages)
			delete image;
	}

	public override void Init()
	{
		//DecodeGen.GenerateEncode();
		//DecodeGen.GenerateDecode();

		//TestSignalEncoding();

		base.Init();

		
		DarkTheme darkTheme = new DarkTheme();
		darkTheme.Init();
		ThemeFactory.mDefault = darkTheme;

		BFWindowBase.Flags windowFlags = .Border | //.SysMenu | //| .CaptureMediaKeys |
		    .Caption | .Minimize | .QuitOnClose | .Resizable |
		    .SysMenu | .Menu;

		mSmFont = new Font();
		mSmFont.Load("Consolas", 12);
		mSmFont.mEllipsis = "+";

		mSigUIImage = Image.LoadFromFile(scope $"{mInstallDir}/images/SigUI.png");
		mSigUIImages = mSigUIImage.CreateImageCels(4, 4);
		mSigBar = mSigUIImages[(.)SigUIImage.SigBar].CreateImageSegment(0, 0, 2, 20);

		/*mFont = new Font();
		float fontSize = 12;
		mFont.Load(scope String(BFApp.sApp.mInstallDir, "fonts/SourceCodePro-Regular.ttf"), fontSize);
		mFont.AddAlternate("Segoe UI Symbol", fontSize);
		mFont.AddAlternate("Segoe UI Historic", fontSize);
		mFont.AddAlternate("Segoe UI Emoji", fontSize);*/

		mMainFrame = new MainFrame();
		mDockingFrame = mMainFrame.mDockingFrame;        

		//mBoard.Load(dialog.FileNames[0]);
		mMainWindow = new WidgetWindow(null, "SigBuddy", 32, 32, 1600, 1200, windowFlags, mMainFrame);
		//mMainWindow.mWindowKeyDownDelegate.Add(new => SysKeyDown);
		mMainWindow.SetMinimumSize(480, 360);
		mMainWindow.mIsMainWindow = true;

		mSigPanel = new SigPanel();
		mSigGroupPanel = new SigGroupPanel();
		mSigListPanel = new SigListPanel();

		CreateDefaultLayout();
		CreateMenu();

		mSigData = new .();
		//mSigData.Load(@"C:\proj\ClockBuddy\fpga\Verilated\vdump.vcd");
		mSigData.Load(@"C:\proj\ClockBuddy\fpga\Verilated\test.vcd");
		//mSigData.Load(@"C:\proj\ClockBuddy\fpga\dump.vcd");

		mSigGroupPanel.RebuildData();
	}

	public void WithDocumentTabbedViewsOf(BFWindow window, delegate void(DarkTabbedView) func)
	{
		var widgetWindow = window as WidgetWindow;
		if (widgetWindow != null)
		{
		    var darkDockingFrame = widgetWindow.mRootWidget as DarkDockingFrame;
		    if (widgetWindow == mMainWindow)
		        darkDockingFrame = mDockingFrame;

		    if (darkDockingFrame != null)
		    {
		        darkDockingFrame.WithAllDockedWidgets(scope (dockedWidget) =>
		            {
		                var tabbedView = dockedWidget as DarkTabbedView;
		                if (tabbedView != null)
		                    func(tabbedView);
		            });
		    }
		}
	}

	public void WithTabsOf(BFWindow window, delegate void(TabbedView.TabButton) func)
	{
		WithDocumentTabbedViewsOf(window, scope (documentTabbedView) =>
			{
			    documentTabbedView.WithTabs(func);
			});
	}

	public void WithTabs(delegate void(TabbedView.TabButton) func)
	{
		for (let window in mWindows)
			WithTabsOf(window, func);
	}

	DarkTabbedView CreateTabbedView()
	{
	    return new DarkTabbedView(null);
	}

	public void CloseDocument(Widget documentPanel)
	{
		bool hasFocus = false;
		
		if ((documentPanel.mWidgetWindow != null) && (documentPanel.mWidgetWindow.mFocusWidget != null))
		{
			if (documentPanel.mWidgetWindow.mFocusWidget.HasParent(documentPanel))
				hasFocus = true;
		}

		DarkTabbedView tabbedView = null;
		DarkTabbedView.DarkTabButton tabButton = null;
		WithTabs(scope [&] (tab) =>
		    {
		        if (tab.mContent == documentPanel)
		        {
		            tabbedView = (DarkTabbedView)tab.mTabbedView;
		            tabButton = (DarkTabbedView.DarkTabButton)tab;
		        }
		    });

		tabbedView.RemoveTab(tabButton);
		var nextTab = tabbedView.GetActiveTab();
		if (nextTab != null)
		{
			nextTab.Activate(hasFocus);
		}
	}

	TabbedView.TabButton SetupTab(TabbedView tabView, String name, float width, Widget content, bool ownsContent) // 2
	{
		int tabIdx = tabView.mTabs.Count;

		TabbedView.TabButton tabButton = tabView.AddTab(name, width, content, ownsContent, tabIdx);
		if ((var panel = content as Panel) && (var darkTabButton = tabButton as DarkTabbedView.DarkTabButton))
		{
			darkTabButton.mTabWidthOffset = panel.TabWidthOffset;
		}
		tabButton.mCloseClickedEvent.Add(new () => CloseDocument(content)); // 1
		return tabButton;
	}

	public void CreateDefaultLayout()
	{
		TabbedView groupTabbedView = CreateTabbedView();
		groupTabbedView.SetRequestedSize(GS!(280), GS!(200));
		groupTabbedView.mWidth = GS!(200);
		mDockingFrame.AddDockedWidget(groupTabbedView, null, .Left);
		SetupTab(groupTabbedView, "Groups", GS!(150), mSigGroupPanel, false);

		/*TabbedView sigTabbedView = CreateTabbedView();
		sigTabbedView.SetRequestedSize(GS!(200), GS!(200));
		sigTabbedView.mWidth = GS!(200);
		sigTabbedView.mIsFillWidget = true;
		mDockingFrame.AddDockedWidget(sigTabbedView, groupTabbedView, .Right);
		SetupTab(sigTabbedView, "Waveforms", GS!(150), mSigPanel, false);*/
		mSigPanel.mIsFillWidget = true;
		//mSigPanel.SetRequestedSize(GS!(600), GS!(200));
		//mSigPanel.mWidth = GS!(800);
		//mDockingFrame.RehupSize();
		mDockingFrame.AddDockedWidget(mSigPanel, groupTabbedView, .Right);
		

		TabbedView sigListTabbedView = CreateTabbedView();
		sigListTabbedView.SetRequestedSize(GS!(200), GS!(200));
		sigListTabbedView.mWidth = GS!(200);
		mDockingFrame.AddDockedWidget(sigListTabbedView, groupTabbedView, .Bottom);
		SetupTab(sigListTabbedView, "Signals", GS!(150), mSigListPanel, false);

		groupTabbedView.mSizePriority *= 0.5f;
		mDockingFrame.RehupSize();
	}

	void CreateMenu()
	{
		SysMenu root = mMainWindow.mSysMenu;

		var subItem = root.AddMenuItem("&File");
		subItem.AddMenuItem("&Open...", "Ctrl+O");

		subItem = root.AddMenuItem("&Edit");
	}
}

static
{
	public static SBApp gApp;
}
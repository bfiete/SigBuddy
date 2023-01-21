using System;
using Beefy;
using Beefy.theme.dark;
using Beefy.theme;
using Beefy.gfx;
using Beefy.widgets;
using Beefy.sys;
using SigBuddy.ui;
using System.Diagnostics;
using Beefy.utils;
using System.IO;

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

	public String mSignalFilePath ~ delete _;
	public String mWorkspaceFilePath ~ delete _;

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
		//Load(@"C:\proj\ClockBuddy\fpga\Verilated\vdump.vcd");

		//for (int i < 10)
			Load(@"C:\proj\ClockBuddy\fpga\Verilated\vdump.sigw");

		//Load(@"C:\proj\ClockBuddy\fpga\Verilated\test.vcd");
		//Load(@"C:\proj\ClockBuddy\fpga\Verilated\test.sigw");

		//Load(@"C:\proj\ClockBuddy\fpga\dump.vcd");
		//Load(@"C:\proj\ClockBuddy\fpga\dump.sigw");

		//Load(scope $"{mInstallDir}test.sigw");
	}

	void UpdateTitle(StringView titleOverride = default)
	{
		String title = scope String();
		title.Append("SigBuddy");

		var fileName = scope String();

		if (mWorkspaceFilePath != null)
			Path.GetFileName(mWorkspaceFilePath, fileName);
		else if (mSignalFilePath != null)
			Path.GetFileName(mSignalFilePath, fileName);

		if (!fileName.IsEmpty)
		{
			title.Append(" - ");
			title.Append(fileName);
		}

		mMainWindow.SetTitle(title);
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

	public enum MessageBeepType
	{
	    Default = -1,
	    Ok = 0x00000000,
	    Error = 0x00000010,
	    Question = 0x00000020,
	    Warning = 0x00000030,
	    Information = 0x00000040,
	}

	public static void Beep(MessageBeepType type)
	{
#if BF_PLATFORM_WINDOWS && !CLI
		MessageBeep(type);
#endif        	
	}

#if BF_PLATFORM_WINDOWS
	[Import("user32.lib"), CLink, CallingConvention(.Stdcall)]
	public static extern bool MessageBeep(MessageBeepType type);
#endif

	void Fail(String error)
	{
		Beep(MessageBeepType.Error);

		Dialog dialog = ThemeFactory.mDefault.CreateDialog("ERROR", error, DarkTheme.sDarkTheme.mIconError);
		dialog.mDefaultButton = dialog.AddButton("OK");
		dialog.mEscButton = dialog.mDefaultButton;
		dialog.mWindowFlags |= .Modal;
		//dialog.PopupWindow(parentWindow ?? GetCurrentWindow());
		dialog.PopupWindow(mMainWindow);
	}

	bool SaveWorkspaceAs()
	{
		SaveFileDialog dialog = scope .();
		dialog.SetFilter("Workspace (*.sigw)|*.sigw");
		//dialog.ValidateNames = true;
		//if (!fullDir.IsEmpty)
			//dialog.InitialDirectory = fullDir;

		/*if (sourceViewPanel.mFilePath != null)
		{
			String ext = scope .();
			Path.GetExtension(sourceViewPanel.mFilePath, ext);
			dialog.DefaultExt = ext;

			String fileName = scope .();
			Path.GetFileName(sourceViewPanel.mFilePath, fileName);
			dialog.FileName = fileName;
		}*/

		if (mSignalFilePath != null)
		{
			var dirPath = Path.GetDirectoryPath(mSignalFilePath, .. scope .());
			dialog.InitialDirectory = dirPath;
		}

		dialog.DefaultExt = ".sigw";

		if (mWorkspaceFilePath != null)
			dialog.FileName = mWorkspaceFilePath;
		else if (mSignalFilePath != null)
		{
			String fileName = scope .();
			Path.GetFileNameWithoutExtension(mSignalFilePath, fileName);
			fileName.Append(".sigw");
			dialog.FileName = fileName;
		}

		//dialog.SetFilter("Beef projects (BeefProj.toml)|BeefProj.toml");

		dialog.OverwritePrompt = true;
		if (dialog.ShowDialog(mMainWindow).GetValueOrDefault() != .OK)
			return false;

		DeleteAndNullify!(mWorkspaceFilePath);
		mWorkspaceFilePath = new .(dialog.FileNames[0]);
		SaveWorkspace();

		return true;
	}

	void CreateMenu()
	{
		SysMenu root = mMainWindow.mSysMenu;

		var fileMenu = root.AddMenuItem("&File");
		fileMenu.AddMenuItem("&Open...", "Ctrl+O");

		var subItem = fileMenu.AddMenuItem("&Save Workspace", "Ctrl+S");
		subItem.mOnMenuItemSelected.Add(new (menu) =>
			{
				SaveWorkspace();
			});

		subItem = fileMenu.AddMenuItem("Close Workspace");
		subItem.mOnMenuItemSelected.Add(new (menu) =>
			{
				CloseWorkspace();
			});

		fileMenu = root.AddMenuItem("&Edit");
	}

	void LoadSignal(StringView path)
	{
		DeleteAndNullify!(mSignalFilePath);

		Stopwatch sw = scope .();
		sw.Start();

		//var pfi = Profiler.StartSampling().GetValueOrDefault();

		if (mSigData.Load(path) case .Err)
		{
			Fail(scope $"Failed to load '{path}'");
			return;
		}

		//pfi.Dispose();

		sw.Stop();
		Debug.WriteLine($"Loading time: {sw.ElapsedMilliseconds}ms");

		mSignalFilePath = new .(path);
		mSigPanel.Rebuild();
		mSigGroupPanel.RebuildData();

		UpdateTitle();
	}

	void Load(StringView path)
	{
		Debug.WriteLine($"Loading {path}...");

		if (path.EndsWith(".sigw", .OrdinalIgnoreCase))
		{
			DeleteAndNullify!(mWorkspaceFilePath);
			if (LoadWorkspace(path) case .Err)
				Fail(scope $"Failed to load workspace '{path}'");
			return;
		}

		LoadSignal(path);
	}

	void CloseWorkspace()
	{
		mSigPanel.mEntries.ClearAndDeleteItems();
		mSigPanel.mSigActiveListPanel.RebuildListView();

		DeleteAndNullify!(mSignalFilePath);
		DeleteAndNullify!(mWorkspaceFilePath);

		mSigGroupPanel.Clear();
		mSigListPanel.Clear();

		delete mSigData;
		mSigData = new SigData();

		UpdateTitle();
	}

	Result<void> LoadWorkspace(StringView path)
	{
		CloseWorkspace();

		StructuredData sd = scope .();
		if (sd.Load(path) case .Err(let err))
		{
			return .Err;
		}

		mWorkspaceFilePath = new .(path);

		var sigFile = sd.GetString("SignalFile", .. scope .());
		if (!sigFile.IsEmpty)
		{
			var workspaceDir = Path.GetDirectoryPath(path, .. scope .());
			var signalFilePath = Path.GetAbsolutePath(sigFile, workspaceDir, .. scope .());
			LoadSignal(signalFilePath);
		}

		var sigViewPanel = mSigPanel.mSigViewPanel;

		float tickOfs = 0;
		sd.Get("TickOfs", ref tickOfs);
		sigViewPanel.mTickOfs = tickOfs;

		float scale = 1.0f;
		sd.Get("Scale", ref scale);
		sigViewPanel.mScale = scale;

		sigViewPanel.Clamp();

		for (var entry in sd.Enumerate("Entries"))
		{
			SigPanel.Entry entry = null;

			var signalName = sd.GetString("Name", .. scope .());
			if (!String.IsNullOrEmpty(signalName))
			{
				var signal = mSigData.GetSignal(signalName);
				if (signal != null)
				{
					entry = new SigPanel.Entry();
					entry.mSignal = signal;
					mSigPanel.mEntries.Add(entry);
				}	
			}

			if (entry != null)
			{
				uint32 color = (.)sd.GetInt("Color");
				if (color != 0)
					entry.mColor = color;

				entry.mDataFormat = sd.GetEnum<SigPanel.DataFormat>("Format");
			}
		}

		mSigPanel.Rebuild();
		mSigPanel.mSigActiveListPanel.RebuildListView();

		UpdateTitle();

		return .Ok;
	}

	Result<void> SaveWorkspace(StringView path)
	{
		StructuredData sd = scope .();

		sd.CreateNew();

		//using (sd.CreateObject())
		{
			if (mSignalFilePath != null)
			{
				var workspaceDir = Path.GetDirectoryPath(path, .. scope .());
				var sigRelPath = Path.GetRelativePath(mSignalFilePath, workspaceDir, .. scope .());
				sd.Add("SignalFile", sigRelPath);
			}

			var sigViewPanel = mSigPanel.mSigViewPanel;
			sd.Add("TickOfs", sigViewPanel.mTickOfs);
			if (sigViewPanel.mCursorTick != null)
				sd.Add("CursorTick", sigViewPanel.mCursorTick.Value);
			sd.Add("Scale", sigViewPanel.mScale);

			using (sd.CreateArray("Entries"))
			{
				for (var entry in mSigPanel.mEntries)
				{
					using (sd.CreateObject())
					{
						var signalName = entry.mSignal.GetFullName(.. scope .());
						sd.Add("Name", signalName);
						sd.ConditionalAdd("Format", entry.mDataFormat);
						sd.ConditionalAdd("Color", entry.mColor, 0xFF00FF00);
					}
				}
			}
		}

		String tomlString = scope String();
		sd.ToTOML(tomlString);
		if (File.WriteAllText(path, tomlString) case .Err)
			return .Err;

		return .Ok;
	}

	void SaveWorkspace()
	{
		if (mWorkspaceFilePath == null)
		{
			SaveWorkspaceAs();
			return;
		}

		if (SaveWorkspace(mWorkspaceFilePath) case .Err)
			Fail(scope $"Failed to write workspace '{mWorkspaceFilePath}'");
	}
}

static
{
	public static SBApp gApp;
}
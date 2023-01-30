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
using System.Collections;

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
			//Load(@"C:\proj\ClockBuddy\fpga\Verilated\vdump.sigw");
		//Load(@"C:\proj\ClockBuddy\fpga\Verilated\vdump.sig");
		//for (int i < 10)
			Load(@"C:\proj\ClockBuddy\fpga\Verilated\vdump2.sigw");

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

	public void Fail(String error)
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

		var subItem = fileMenu.AddMenuItem("&Open...", "Ctrl+O");
		subItem.mOnMenuItemSelected.Add(new (menu) =>
			{
				Load();
			});

		subItem = fileMenu.AddMenuItem("&Reload", "Shift+Ctrl+R");
		subItem.mOnMenuItemSelected.Add(new (menu) =>
			{
				Reload();
			});

		subItem = fileMenu.AddMenuItem("&Save Workspace", "Ctrl+S");
		subItem.mOnMenuItemSelected.Add(new (menu) =>
			{
				SaveWorkspace();
			});

		subItem = fileMenu.AddMenuItem("Close Workspace");
		subItem.mOnMenuItemSelected.Add(new (menu) =>
			{
				CloseWorkspace();
			});

		var editMenu = root.AddMenuItem("&Edit");

		subItem = editMenu.AddMenuItem("Go to Time...", "Ctrl+G");
		subItem.mOnMenuItemSelected.Add(new (menu) =>
			{
				ShowGotoDialog();
			});

		subItem = editMenu.AddMenuItem("&Find Signal Value...", "Ctrl+F");
		subItem.mOnMenuItemSelected.Add(new (menu) =>
			{
				FindSignalValue();
			});
		subItem = editMenu.AddMenuItem("Find &Next", "F3");
		subItem.mOnMenuItemSelected.Add(new (menu) =>
			{
				gApp.mSigPanel.mSigViewPanel.FindNext();
			});
		subItem = editMenu.AddMenuItem("Find &Prev", "Shift-F3");
		subItem.mOnMenuItemSelected.Add(new (menu) =>
			{
				gApp.mSigPanel.mSigViewPanel.FindPrev();
			});

		var bookmarkItem = editMenu.AddMenuItem("Bookmar&ks");
		subItem = bookmarkItem.AddMenuItem("&Toggle Bookmark", "Ctrl+F2");
		subItem = bookmarkItem.AddMenuItem("&Next Bookmark", "F2");
		subItem = bookmarkItem.AddMenuItem("&Prev Bookmark", "F2");
		subItem = bookmarkItem.AddMenuItem("&Clear Bookmarks");
	}

	void LoadSignal(StringView path)
	{
		DeleteAndNullify!(mSignalFilePath);

		Stopwatch sw = scope .();
		sw.Start();

		ProfileInstance pfi = default;
		//pfi = Profiler.StartSampling().GetValueOrDefault();

		WaveFormat waveFormat = null;

		if (path.EndsWith(".vcd", .OrdinalIgnoreCase))
			waveFormat = scope:: VCDFormat(mSigData);
		if (path.EndsWith(".sig", .OrdinalIgnoreCase))
			waveFormat = scope:: SIGFormat(mSigData);

		if (waveFormat == null)
		{
			Fail(scope $"Unsupported wave file format '{path}'");
			return;
		}

		if (waveFormat.Load(path) case .Err)
		{
			Fail(scope $"Failed to load '{path}'");
			return;
		}

		pfi.Dispose();

		sw.Stop();
		Debug.WriteLine($"Loading time: {sw.ElapsedMilliseconds}ms");

		mSignalFilePath = new .(path);
		mSigPanel.Rebuild();
		mSigGroupPanel.RebuildData();

		UpdateTitle();
	}

	public void Load()
	{
		OpenFileDialog dialog = scope .();
		dialog.SetFilter("All Files|*.*|Workspace (*.sigw)|*.sigw|VCD File (*.vcd)|*.vcd");

		if (dialog.ShowDialog() case .Err)
			return;
		if (dialog.FileNames.IsEmpty)
			return;
		Load(dialog.FileNames[0]);
	}

	public void Reload()
	{
		StructuredData sd = scope .();
		SaveWorkspace(sd, mInstallDir).IgnoreError();
		var toml = sd.ToTOML(.. scope .());

		sd = scope .();
		sd.LoadFromString(toml);
		LoadWorkspace(sd, mInstallDir).IgnoreError();
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

	void ClearWorkspaceData()
	{
		mSigPanel.mEntries.ClearAndDeleteItems();
		mSigPanel.mSigActiveListPanel.Clear();
		mSigPanel.mSigActiveListPanel.RebuildListView();

		var sigViewPanel = mSigPanel.mSigViewPanel;
		sigViewPanel.mLastFindEntry = null;
		DeleteAndNullify!(sigViewPanel.mLastFindData);

		mSigGroupPanel.Clear();
		mSigListPanel.Clear();

		delete mSigData;
		mSigData = new SigData();
	}

	void CloseWorkspace()
	{
		ClearWorkspaceData();

		DeleteAndNullify!(mSignalFilePath);
		DeleteAndNullify!(mWorkspaceFilePath);

		UpdateTitle();
	}

	Result<void> LoadWorkspace(StructuredData sd, String workspaceDir)
	{
		ClearWorkspaceData();

		var sigFile = sd.GetString("SignalFile", .. scope .());
		if (!sigFile.IsEmpty)
		{
			var signalFilePath = Path.GetAbsolutePath(sigFile, workspaceDir, .. scope .());
			LoadSignal(signalFilePath);
		}

		var sigViewPanel = mSigPanel.mSigViewPanel;

		float tickOfs = 0;
		sd.Get("TickOfs", ref tickOfs);
		sigViewPanel.mDestTickOfs = tickOfs;

		if (sd.Contains("CursorTick"))
		{
			float cursorTick = 0;
			sd.Get("CursorTick", ref cursorTick);
			sigViewPanel.CursorTick = cursorTick;
		}

		float scale = 1.0f;
		sd.Get("Scale", ref scale);
		sigViewPanel.mScale = scale;

		float vertPos = 0;
		sd.Get("VertPos", ref vertPos);

		String lastFindEntry = sd.Get("LastFindEntry", .. scope .());
		if (!lastFindEntry.IsEmpty)
		{
			delete sigViewPanel.mLastFindData;
			sigViewPanel.mLastFindData = new .();
			for (sd.Enumerate("LastFindData"))
			{
				sigViewPanel.mLastFindData.Add((.)sd.GetCurInt());
			}
		}

		sigViewPanel.Clamp();

		void LoadEntries(SigPanel.Entry parentEntry, List<SigPanel.Entry> entries)
		{
			for (var entry in sd.Enumerate("Entries"))
			{
				SigPanel.Entry entry = null;
				Signal signal = null;

				var signalName = sd.GetString("Signal", .. scope .());
				if (!String.IsNullOrEmpty(signalName))
				{
					signal = mSigData.GetSignal(signalName);
					if (signal == null)
						continue; // Remove dead signals
				}

				SigActiveListPanel.ListViewState state = default;

				entry = new SigPanel.Entry();
				entry.mParent = parentEntry;
				entry.mSignal = signal;
				entries.Add(entry);

				var name = sd.GetString("Name", .. scope .());
				if ((!name.IsEmpty) || (entry.mSignal == null))
					entry.mName = new String(name);

				uint32 color = (.)sd.GetInt("Color");
				if (color != 0)
					entry.mColor = color;

				entry.mDataFormat = sd.GetEnum<SigUtils.DataFormat>("Format");

				if (sd.Contains("Focused"))
					state.mFocused = true;
				if (sd.Contains("Selected"))
					state.mSelected = true;

				if (sd.Contains("IsOpen"))
				{
					entry.mChildren = new .();
					sd.Get("IsOpen", ref state.mIsOpen);
				}

				if (sd.Contains("Entries"))
				{
					LoadEntries(entry, entry.mChildren);
				}

				if ((!lastFindEntry.IsEmpty) && (signalName == lastFindEntry))
					sigViewPanel.mLastFindEntry = entry;

				mSigPanel.mSigActiveListPanel.mListViewStates[entry] = state;
			}
		}

		LoadEntries(null, mSigPanel.mEntries);

		mSigPanel.Rebuild();
		mSigPanel.mSigActiveListPanel.RebuildListView();
		sigViewPanel.SnapDrawPositions();
		sigViewPanel.UpdateScrollbar();
		//sigViewPanel.mVertScrollbar.ScrollTo(vertPos);

		/*if (focusedEntry != null)
		{
			mSigPanel.mSigActiveListPanel.mListView.GetRoot().WithItems(scope (item) =>
				{
					var activeItem = (SigActiveListViewItem)item;
					var entry = activeItem.mEntry;
					if (entry == focusedEntry)
						activeItem.Focused = true;
				});
		}*/

		return .Ok;
	}

	Result<void> LoadWorkspace(StringView path)
	{
		StructuredData sd = scope .();
		if (sd.Load(path) case .Err(let err))
		{
			return .Err;
		}

		mWorkspaceFilePath = new .(path);

		var workspaceDir = Path.GetDirectoryPath(path, .. scope .());
		if (LoadWorkspace(sd, workspaceDir) case .Err)
			return .Err;

		UpdateTitle();

		return .Ok;
	}

	Result<void> SaveWorkspace(StructuredData sd, String workspaceDir)
	{
		sd.CreateNew();

		if (mSignalFilePath != null)
		{
			var sigRelPath = Path.GetRelativePath(mSignalFilePath, workspaceDir, .. scope .());
			sd.Add("SignalFile", sigRelPath);
		}

		var sigViewPanel = mSigPanel.mSigViewPanel;
		sd.Add("TickOfs", sigViewPanel.mDestTickOfs);
		if (sigViewPanel.mCursorTick != null)
			sd.Add("CursorTick", sigViewPanel.mCursorTick.Value);
		sd.Add("Scale", sigViewPanel.mScale);
		sd.Add("VertPos", sigViewPanel.mVertScrollbar.mContentPos);

		if ((sigViewPanel.mLastFindEntry != null) && (sigViewPanel.mLastFindEntry.mSignal != null))
		{
			sd.Add("LastFindEntry", sigViewPanel.mLastFindEntry.mSignal.GetFullName(.. scope .()));
			using (sd.CreateArray("LastFindData"))
			{
				for (var val in sigViewPanel.mLastFindData)
					sd.Add(val);
			}
		}

		if (gApp.mSigPanel.mEntryListViewDirty)
			gApp.mSigPanel.Update();

		void SaveEntries(SigActiveListViewItem listViewItem)
		{
			using (sd.CreateArray("Entries"))
			{
				for (var item in listViewItem.mChildItems)
				{
					var activeItem = (SigActiveListViewItem)item;
					var entry = activeItem.mEntry;

					using (sd.CreateObject())
					{
						if (entry.mName != null)
							sd.Add("Name", entry.mName);
						if (entry.mSignal != null)
						{
							var signalName = entry.mSignal.GetFullName(.. scope .());
							sd.Add("Signal", signalName);
						}
						sd.ConditionalAdd("Format", entry.mDataFormat);
						sd.ConditionalAdd("Color", entry.mColor, 0xFF00FF00);
						if (activeItem.Focused)
							sd.Add("Focused", true);
						else if (activeItem.Selected)
							sd.Add("Selected", true);

						if (activeItem.mChildItems != null)
						{
							sd.Add("IsOpen", activeItem.mOpenButton.mIsOpen);
							SaveEntries(activeItem);
						}
					}
				}
			}
		}

		SaveEntries((.)mSigPanel.mSigActiveListPanel.mListView.GetRoot());

		return .Ok;
	}

	Result<void> SaveWorkspace(StringView path)
	{
		var workspaceDir = Path.GetDirectoryPath(path, .. scope .());

		StructuredData sd = scope .();
		if (SaveWorkspace(sd, workspaceDir) case .Err)
			return .Err;

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

	void FindSignalValue()
	{
		FindDialog findDialog = new .();
		findDialog.PopupWindow(mMainWindow);
	}

	void ShowGotoDialog()
	{
		GotoDialog gotoDialog = new .();
		gotoDialog.PopupWindow(mMainWindow);
	}

	public override void Update(bool batchStart)
	{
		base.Update(batchStart);
		if (ThemeFactory.mDefault != null)
			ThemeFactory.mDefault.Update();
	}
}

static
{
	public static SBApp gApp;
}
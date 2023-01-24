using Beefy.theme.dark;
using Beefy.events;
using Beefy.widgets;
using Beefy.gfx;
using Beefy.theme;
using System;
using System.Collections;
using System.Diagnostics;
using Beefy.geom;

namespace SigBuddy.ui;

class SigActiveListView : DarkListView
{
	protected override ListViewItem CreateListViewItem()
	{
		return new SigActiveListViewItem();
	}

	public override void MouseWheel(float x, float y, float deltaX, float deltaY)
	{
		base.MouseWheel(x, y, deltaX, deltaY);

		var sigViewPanel = gApp.mSigPanel.mSigViewPanel;
		sigViewPanel.mVertScrollbar.Scroll(-deltaY * GS!(16));
	}

	public override void KeyDown(KeyCode keyCode, bool isRepeat)
	{
		var sigViewPanel = gApp.mSigPanel.mSigViewPanel;

		switch (keyCode)
		{
		case .Left, .Right, .Home, .End, .PageUp, .PageDown:
			sigViewPanel.KeyDown(keyCode, isRepeat);
			return;
		default:
		}

		base.KeyDown(keyCode, isRepeat);
	}
}

class SigActiveListViewItem : DarkListViewItem
{
	public SigPanel.Entry mEntry;

	public override void Init(ListView listView)
	{
		base.Init(listView);
		mSelfHeight = GS!(20);
	}

	public override void Resize(float x, float y, float width, float height)
	{
		base.Resize(x, y, width, height);

		if (mEntry != null)
		{
			SelfToOtherTranslate(mListView.mScrollContent, 0, 0, var transX, var transY);
			mEntry.mY = transY + GS!(20);
		}
	}

	public override void KeyDown(KeyCode keyCode, bool isRepeat)
	{
		base.KeyDown(keyCode, isRepeat);
	}
}

class SigActiveListPanel : Panel
{
	public SigPanel mSigPanel;
	public SigActiveListView mListView;

	public this()
	{
		mListView = new .();
		//mListView.mProjectPanel = this;
		//mListView.mOnEditDone.Add(new => HandleEditDone);

		mListView.SetShowHeader(true);
		mListView.InitScrollbars(false, false);
		//mListView.mHorzScrollbar.mPageSize = GS!(100);
		//mListView.mHorzScrollbar.mContentSize = GS!(500);
		//mListView.mVertScrollbar.mPageSize = GS!(100);
		//mListView.mVertScrollbar.mContentSize = GS!(500);
		mListView.mLabelX = GS!(6);
		//mListView.mIconX = GS!(20);
		//mListView.mChildIndent = GS!(12);
		mListView.UpdateScrollbars();
		//mListView.mOnFocusChanged.Add(new => FocusChangedHandler);

		//mListView.mOnDragEnd.Add(new => HandleDragEnd);
		//mListView.mOnDragUpdate.Add(new => HandleDragUpdate);

		AddWidget(mListView);

		mListView.mOnMouseClick.Add(new => ListViewClicked);
		mListView.mOnMouseDown.Add(new => ListViewMouseDown);
		mListView.mOnItemMouseDown.Add(new => ListViewItemMouseDown);
		mListView.mOnItemMouseClicked.Add(new => ListViewItemClicked);

		mListView.mOnDragEnd.Add(new => HandleDragEnd);
		mListView.mOnDragUpdate.Add(new => HandleDragUpdate);

		mListView.AddColumn(GS!(100), "Name");
		mListView.AddColumn(GS!(100), "Value");
	}

	void ListViewItemMouseDown(ListViewItem item, float x, float y, int32 btnNum, int32 clickCount)
	{
		var item;
		if (item.mColumnIdx != 0)
		    item = item.GetSubItem(0);

		if (btnNum == 1)
		{
			if (item.Selected)
				return; // Leave alone
		}

		mListView.GetRoot().SelectItem(item, true);
		mListView.SetFocus();

		if (btnNum == 1)
		{
			/*Widget widget = (DarkListViewItem)theEvent.mSender;
			float clickX = theEvent.mX;
			float clickY = widget.mHeight + GS!(2);
		    float aX, aY;
		    widget.SelfToOtherTranslate(mListView.GetRoot(), clickX, clickY, out aX, out aY);*/
		    //ShowRightClickMenu(mListView, aX, aY);
		}
		else
		{                
		    //if (anItem.IsParent)
		        //anItem.Selected = false;
		}
	}

	void ShowDebugInfo()
	{
		mListView.GetRoot().WithSelectedItems(scope (item) =>
			{
				var activeItem = (SigActiveListViewItem)item;

				var signal = activeItem.mEntry.mSignal;
				Debug.WriteLine($"Signal: {signal.mName} NumChunks: {signal.mSignalData.mChunks.Count}");

				int64 lodTotalSize = 0;
				for (int lodIdx = -1; true; lodIdx++)
				{
					int64 totalSize = 0;
					int64 totalWantMin = 0;
					int64 totalMin = 0;
					int32 entryCount = 0;

					for (var chunk in signal.mSignalData.mChunks)
					{
						var chunkData = chunk.mRawData;
						if (lodIdx >= 0)
						{
							if (lodIdx >= chunk.mLODData.Count)
								continue;
							chunkData = chunk.mLODData[lodIdx];
						}
						totalSize += chunkData.mBuffer.Count;
						totalMin += chunkData.mMinDelta + chunkData.mDeltaEncodeOffset;
						totalWantMin += chunkData.mWantMinTickDelta;
						entryCount++;
					}

					if (totalSize == 0)
						break;
					if (lodIdx != -1)
						lodTotalSize += totalSize;
					Debug.WriteLine($"[{lodIdx}] Size: {(totalSize + 1023)/1024}k MinTickDelta:{totalMin/entryCount} WantMinTickDelta:{totalWantMin/entryCount}");
				}
				Debug.WriteLine($"Total LOD Size: {(lodTotalSize + 1023)/1024}k");

				if (double cursorTick = gApp.mSigPanel.mSigViewPanel.mCursorTick)
				{
					Debug.WriteLine($"Cursor: {cursorTick}");
					for (var chunk in signal.mSignalData.mChunks)
					{
						if ((cursorTick < chunk.mStartTick) || (cursorTick > chunk.mEndTick))
							continue;

						Debug.WriteLine($"Chunk {chunk} {chunk.mStartTick}-{chunk.mEndTick}");

						int prevIdx = -1;
						for (int scaleIdx < chunk.mLODIndices.Count)
						{
							if (chunk.mLODIndices[scaleIdx] != prevIdx)
							{
								prevIdx = chunk.mLODIndices[scaleIdx];
								Debug.WriteLine($"{prevIdx} at {1<<scaleIdx}");
							}
						}
						Debug.WriteLine($"End at {1<<(chunk.mLODIndices.Count-1)}");
					}
				}
			});
	}

	class ColorSelectWidget : Widget
	{
		public Event<delegate void(uint32 color)> mOnColorChange ~ _.Dispose();

		public List<uint32> mColors = new .() ~ delete _;

		public Point? mCursorPos;
		public uint32? mOverColor;

		public this()
		{
			mColors.Add(0xFF00FF00);
			mColors.Add(0xFF4040FF);
			mColors.Add(0xFFFF0000);
			mColors.Add(0xFF00FFFF);
			mColors.Add(0xFFFF00FF);
			mColors.Add(0xFFFFFF00);
			mColors.Add(0xFFFF8C00);
			mColors.Add(0xFFFFFFFF);
		}

		public override void Draw(Graphics g)
		{
			/*using (g.PushColor(0x40FF0000))
				g.FillRect(0, 0, mWidth, mHeight);*/

			int cols = 3;

			int size = (int)(mWidth / cols);
			mOverColor = null;

			for (int colorIdx <= mColors.Count)
			{
				Rect rect = .((colorIdx % cols) * size, (colorIdx / cols) * size, size, size);
				rect.Inflate(-GS!(2), -GS!(2));

				uint32 color = (colorIdx < mColors.Count) ? mColors[colorIdx] : 0;

				using (g.PushColor(0xFFD0D0D0))
				{
					if (color == 0)
					{
						g.FillRectGradient(rect.mX, rect.mY, rect.mWidth, rect.mHeight, 0xFF00FF00, 0xFF0000FF, 0xFF0000FF, 0xFFFF4040);
					}
					else
					{
						using (g.PushColor(color))
							g.FillRect(rect.mX, rect.mY, rect.mWidth, rect.mHeight);
					}
				}

				if (mCursorPos != null)
				{
					if (rect.Contains(mCursorPos.Value.x, mCursorPos.Value.y))
					{
						rect.Inflate(2, 2);
						using (g.PushColor(0x80FFFFFF))
							g.OutlineRect(rect.mX, rect.mY, rect.mWidth, rect.mHeight);
						mOverColor = color;
					}
				}
			}
		}

		public override void MouseDown(float x, float y, int32 btn, int32 btnCount)
		{
			base.MouseDown(x, y, btn, btnCount);

			if (mOverColor != null)
				mOnColorChange(mOverColor.Value);

			var menuItem = mParent as DarkMenuItem;
			menuItem?.mMenuWidget.mParentMenuItemWidget.mMenuWidget.Close();
		}

		public override void MouseMove(float x, float y)
		{
			base.MouseMove(x, y);
			mCursorPos = .(x, y);
		}

		public override void MouseLeave()
		{
			base.MouseLeave();
			mCursorPos = null;
		}
	}

	public MenuWidget ShowRightClickMenu(Widget relWidget, float x, float y, bool itemClicked)
	{
		Menu menu = new Menu();

		if (itemClicked)
		{
			var subMenu = menu.AddItem("Data Format");

			HashSet<SigUtils.DataFormat> usedFormats = scope .();
			mListView.GetRoot().WithSelectedItems(scope (item) =>
				{
					var activeItem = (SigActiveListViewItem)item;
					usedFormats.Add(activeItem.mEntry.DataFormat);
				});

			//Enum.GetEnumerator(); // SigPanel.DataFormat
			for (var value in Enum.GetEnumerator(typeof(SigUtils.DataFormat)))
			{
				if (value.value == 0)
					continue;

				var item = subMenu.AddItem(value.name);
				if (usedFormats.Contains((.)value.value))
					item.mIconImage = DarkTheme.sDarkTheme.GetImage(.Check);

				item.mOnMenuItemSelected.Add(new (menu) =>
					{
						mListView.GetRoot().WithSelectedItems(scope (item) =>
							{
								var activeItem = (SigActiveListViewItem)item;
								activeItem.mEntry.mDataFormat = (.)value.value;
								gApp.mSigPanel.UpdateValues();
							});
					});
			}

			ColorSelectWidget colorSelectWidget = new ColorSelectWidget();
			colorSelectWidget.Resize(0, 0, 108, 108);
			colorSelectWidget.mOnColorChange.Add(new (selColor) =>
				{
					int32 colorCount = (.)colorSelectWidget.mColors.Count;

					Dictionary<uint32, int> colorToIdx = scope .();
					for (var color in colorSelectWidget.mColors)
					{
						colorToIdx[color] = @color.Index;
					}

					int32[] colorCounts = scope int32[colorCount];

					mListView.GetRoot().WithItems(scope (item) =>
						{
							var activeItem = (SigActiveListViewItem)item;
							if (!activeItem.Selected)
							{
								var entry = activeItem.mEntry;
								if (colorToIdx.TryGetValue(entry.mColor, var idx))
									colorCounts[idx]++;
							}
						});

					mListView.GetRoot().WithSelectedItems(scope (item) =>
						{
							var activeItem = (SigActiveListViewItem)item;
							var entry = activeItem.mEntry;

							uint32 newColor = selColor;

							if (selColor == 0)
							{
								newColor = colorSelectWidget.mColors[0];
								int32 lowestCount = colorCounts[0];

								for (int32 colorIdx < colorCount)
								{
									if (colorCounts[colorIdx] < lowestCount)
									{
										newColor = colorSelectWidget.mColors[colorIdx];
										lowestCount = colorCounts[colorIdx];
									}
								}
							}

							if (colorToIdx.TryGetValue(newColor, var idx))
								colorCounts[idx]++;
							
							entry.mColor = newColor;
							entry.mColorUndef = 0;
						});
				});

			subMenu = menu.AddItem("Color");
			subMenu.AddWidgetItem(colorSelectWidget);
			
			//menu.AddItem("Show in Selector");

			subMenu = menu.AddItem("Delete");
			subMenu.mOnMenuItemSelected.Add(new (menu) =>
				{
					var root = mListView.GetRoot();

					int checkIdx = 0;
					while (checkIdx < root.GetChildCount())
					{
						var listViewItem = (SigActiveListViewItem)root.GetChildAtIndex(checkIdx);
						if (listViewItem.Selected)
						{
							gApp.mSigPanel.mEntries.Remove(listViewItem.mEntry);
							delete listViewItem.mEntry;
							root.RemoveChildItemAt(checkIdx);
						}
						else
							checkIdx++;
					}
				});

			menu.AddItem();
		}

		var subMenu = menu.AddItem("Delete All");
		subMenu.mOnMenuItemSelected.Add(new (menu) =>
			{
				var root = mListView.GetRoot();
				int checkIdx = 0;
				while (root.GetChildCount() > 0)
				{
					var listViewItem = (SigActiveListViewItem)root.GetChildAtIndex(0);
					gApp.mSigPanel.mEntries.Remove(listViewItem.mEntry);
					delete listViewItem.mEntry;
					root.RemoveChildItemAt(checkIdx);
				}
			});

		MenuWidget menuWidget = ThemeFactory.mDefault.CreateMenuWidget(menu);

		menuWidget.Init(relWidget, x, y);
		
		return menuWidget;
	}

	void ListViewItemClicked(ListViewItem item, float x, float y, int32 btnNum)
	{
		var item;
		if (item.mColumnIdx != 0)
		    item = item.GetSubItem(0);

		//mListView.GetRoot().SelectItemExclusively(item);

		if (btnNum == 1)
		{			
			float clickX = x;
			float clickY = item.mHeight + GS!(2);
		    float aX, aY;
		    item.SelfToOtherTranslate(mListView, clickX, clickY, out aX, out aY);
		    ShowRightClickMenu(mListView, aX, aY, true);
		}
		else
		{                
		    //if (anItem.IsParent)
		        //anItem.Selected = false;
		}
	}

	void ListViewClicked(MouseEvent evt)
	{
		if (evt.mBtn == 1)
		{
		    //float aX, aY;
		    //evt.GetRootCoords(out aX, out aY);
		    ShowRightClickMenu(mListView, evt.mX, evt.mY, false);
		}
	}

	void ListViewMouseDown(MouseEvent evt)
	{
	    // We clicked off all items, so deselect
		//mListView.GetRoot().WithSelectedItems(scope (item) => { item.Selected = false; } );

		
	}

	public override void Resize(float x, float y, float width, float height)
	{
	    base.Resize(x, y, width, height);
	    mListView.Resize(0, 0, mWidth, mHeight);
	}

	public void RebuildListView()
	{
		var rootListViewItem = mListView.GetRoot();
		rootListViewItem.Clear();

		for (var item in mSigPanel.mEntries)
		{
			var listViewItem = rootListViewItem.CreateChildItem() as SigActiveListViewItem;
			listViewItem.mEntry = item;
			listViewItem.Label = item.mSignal.mName;
			listViewItem.AllowDragging = true;

			var subListViewItem = (SigActiveListViewItem)listViewItem.CreateSubItem(1);
			subListViewItem.AllowDragging = true;
			
			//var subListViewItem = listViewItem.CreateSubItem(1);
			//subListViewItem.Label = item.mName;
		}
	}

	public void RebuildEntriesFromListView()
	{
		var rootListViewItem = mListView.GetRoot();
		mSigPanel.mEntries.Clear();

		for (int idx < rootListViewItem.GetChildCount())
		{
			var listViewItem = (SigActiveListViewItem)rootListViewItem.GetChildAtIndex(idx);
			mSigPanel.mEntries.Add(listViewItem.mEntry);
		}
	}

	void HandleDragUpdate(DragEvent evt)
	{
	}

	void HandleDragEnd(DragEvent theEvent)
	{
	    if (theEvent.mDragKind == .None)
	        return;

		if (theEvent.mDragTarget is SigActiveListViewItem)
		{
		    var source = (SigActiveListViewItem)theEvent.mSender;
		    var target = (SigActiveListViewItem)theEvent.mDragTarget;

		    if (source.mListView == target.mListView)
		    {                    
		        if (source == target)
		            return;

				// We're dragging a top-level item into a new position
				source.mParentItem.RemoveChildItem(source, false);
				if (theEvent.mDragKind == .Before) // Before
				    target.mParentItem.InsertChild(source, target);
				else if (theEvent.mDragKind == .After) // After
				    target.mParentItem.AddChild(source, target);

				RebuildEntriesFromListView();
		    }
		}
	}

	public override void Draw(Graphics g)
	{
		g.DrawBox(DarkTheme.sDarkTheme.mImages[(int32)DarkTheme.ImageIdx.Window], 0, 0, mWidth, mHeight);
	}
}
using Beefy.widgets;
using Beefy.gfx;
using Beefy.theme.dark;

namespace SigBuddy.ui;

class StatusBar : Widget
{
	public override void Draw(Graphics g)
	{
		using (g.PushColor(0xFF404060))
			g.FillRect(0, 0, mWidth, mHeight);

		g.SetFont(DarkTheme.sDarkTheme.mSmallFont);
		g.DrawString(StackStringFormat!("FPS: {0}", gApp.mLastFPS), 32, 0);
	}
}
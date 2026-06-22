import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Menu plumbing that lets every menu honour the "Buttons only" setting.
//!
//! Native WatchUi.Menu2 can't refuse touch (a touch-select and a button-select
//! both arrive as the same onSelect), so when the user wants buttons only we show
//! a custom button-driven list instead. showMenu() picks the right one; callers
//! just supply items and a single onChoose(id) callback.
//!
//! An item is a Dictionary: { "label" => String, "sub" => String?, "id" => Object }.

//! Show a menu as a native Menu2 (touch + buttons) or a custom button-only list,
//! per Settings.buttonOnly(). `onChoose` is invoked with the chosen item's id.
function showMenu(title as String, items as Array<Dictionary>, onChoose as Lang.Method) as Void {
    if (Settings.buttonOnly()) {
        var v = new ListMenuView(title, items);
        WatchUi.pushView(v, new ListMenuDelegate(v, onChoose), WatchUi.SLIDE_LEFT);
    } else {
        var menu = new WatchUi.Menu2({:title => title});
        for (var i = 0; i < items.size(); i++) {
            var it = items[i];
            menu.addItem(new WatchUi.MenuItem(it["label"], it["sub"], it["id"], null));
        }
        WatchUi.pushView(menu, new GenericMenu2Delegate(onChoose), WatchUi.SLIDE_LEFT);
    }
}

//! Native-menu delegate that forwards the selected id to a single callback.
class GenericMenu2Delegate extends WatchUi.Menu2InputDelegate {

    private var _onChoose as Lang.Method;

    public function initialize(onChoose as Lang.Method) {
        Menu2InputDelegate.initialize();
        _onChoose = onChoose;
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        _onChoose.invoke(item.getId());
    }
}

//! Custom button-only list menu: a centred selected item (label + subtitle) with
//! the neighbours dimmed above/below. UP/DOWN move, START selects, BACK exits.
class ListMenuView extends WatchUi.View {

    private var _title as String;
    private var _items as Array<Dictionary>;
    private var _sel as Number = 0;

    public function initialize(title as String, items as Array<Dictionary>) {
        View.initialize();
        _title = title;
        _items = items;
    }

    public function move(delta as Number) as Void {
        _sel += delta;
        if (_sel < 0) { _sel = 0; }
        if (_sel >= _items.size()) { _sel = _items.size() - 1; }
    }

    public function selectedId() as Object {
        return _items[_sel]["id"];
    }

    public function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var vc = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        // Title + separator.
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.16).toNumber(), Graphics.FONT_TINY, _title, vc);
        dc.setPenWidth(1);
        dc.drawLine((w * 0.28).toNumber(), (h * 0.24).toNumber(), (w * 0.72).toNumber(), (h * 0.24).toNumber());

        // Neighbour above.
        if (_sel > 0) {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, (h * 0.34).toNumber(), Graphics.FONT_TINY, _items[_sel - 1]["label"], vc);
        }

        // Selected item: label + subtitle.
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.47).toNumber(), Graphics.FONT_SMALL, _items[_sel]["label"], vc);
        var sub = _items[_sel]["sub"];
        if (sub != null) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, (h * 0.57).toNumber(), Graphics.FONT_XTINY, sub, vc);
        }

        // Neighbour below.
        if (_sel < _items.size() - 1) {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, (h * 0.68).toNumber(), Graphics.FONT_TINY, _items[_sel + 1]["label"], vc);
        }

        // Button hints sit on the buttons (always on, since this is button-only).
        drawButtonHint(dc, 0.47, false, "UP", Graphics.COLOR_WHITE, false);
        drawButtonHint(dc, 0.67, false, "DOWN", Graphics.COLOR_WHITE, false);
        drawButtonHint(dc, 0.32, true, "GO", Graphics.COLOR_WHITE, false);
        drawButtonHint(dc, 0.68, true, "BACK", Graphics.COLOR_LT_GRAY, false);
    }
}

//! Drives ListMenuView with buttons only; all touch is consumed (ignored).
class ListMenuDelegate extends WatchUi.BehaviorDelegate {

    private var _view as ListMenuView;
    private var _onChoose as Lang.Method;

    public function initialize(view as ListMenuView, onChoose as Lang.Method) {
        BehaviorDelegate.initialize();
        _view = view;
        _onChoose = onChoose;
    }

    public function onKeyPressed(evt as WatchUi.KeyEvent) as Boolean {
        var k = evt.getKey();
        if (k == WatchUi.KEY_UP) {
            _view.move(-1);
            WatchUi.requestUpdate();
            return true;
        } else if (k == WatchUi.KEY_DOWN) {
            _view.move(1);
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }

    public function onSelect() as Boolean {
        _onChoose.invoke(_view.selectedId());
        return true;
    }

    public function onTap(evt as WatchUi.ClickEvent) as Boolean {
        return true;    // swallow touch
    }

    public function onSwipe(evt as WatchUi.SwipeEvent) as Boolean {
        return true;    // swallow touch
    }
}

//! Base for the custom data-screen delegates: consumes touch (tap/swipe) when the
//! user has chosen buttons only, so a stray tap/swipe can't trigger an action.
//! Buttons still flow through to the subclass behaviours.
class ButtonNavDelegate extends WatchUi.BehaviorDelegate {

    public function initialize() {
        BehaviorDelegate.initialize();
    }

    public function onTap(evt as WatchUi.ClickEvent) as Boolean {
        return Settings.buttonOnly();
    }

    public function onSwipe(evt as WatchUi.SwipeEvent) as Boolean {
        return Settings.buttonOnly();
    }
}

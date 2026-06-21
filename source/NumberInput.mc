import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

//! A friendly numeric spinner.
//!   UP   = increase     DOWN = decrease   (HOLD either to fly through values)
//!   START = confirm     BACK  = cancel
//! Holding a button auto-repeats and accelerates, so big numbers don't mean
//! dozens of taps. Reused for azimuth, range, and future tools.
class NumberInputView extends WatchUi.View {

    private var _prompt as String;     // plain-language line: what to enter and why
    private var _value as Number;
    private var _min as Number;
    private var _max as Number;
    private var _step as Number;
    private var _wrap as Boolean;
    private var _suffix as String;     // drawn after the big number, e.g. "°" or " m"
    private var _padWidth as Number;   // zero-pad the number to this width (0 = none)
    private var _action as String;     // START button hint, e.g. "NEXT" or "DONE"
    private var _hints as HintTimer = new HintTimer();

    public function initialize(prompt as String, value as Number, min as Number, max as Number,
                               step as Number, wrap as Boolean, suffix as String,
                               padWidth as Number, action as String) {
        View.initialize();
        _prompt = prompt;
        _value = value;
        _min = min;
        _max = max;
        _step = step;
        _wrap = wrap;
        _suffix = suffix;
        _padWidth = padWidth;
        _action = action;
    }

    public function onShow() as Void {
        _hints.reset();
    }

    public function onHide() as Void {
        _hints.stop();
    }

    //! Bring the hints back (e.g. when a button is pressed during entry).
    public function bumpHints() as Void {
        _hints.reset();
    }

    public function getValue() as Number {
        return _value;
    }

    //! Adjust by `times` steps in the given direction (+1 up, -1 down).
    public function adjust(direction as Number, times as Number) as Void {
        for (var i = 0; i < times; i++) {
            _value += direction * _step;
            if (_value > _max) {
                _value = _wrap ? _min + (_value - _max - 1) : _max;
            } else if (_value < _min) {
                _value = _wrap ? _max - (_min - _value - 1) : _min;
            }
        }
    }

    public function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_BLACK);
        dc.clear();

        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        var numH = dc.getFontHeight(Graphics.FONT_NUMBER_MEDIUM);

        // What to enter - kept short and up at the top arc, well clear of the
        // START button hint's row (otherwise the two collide on the right).
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (dc.getHeight() * 0.15).toNumber(), Graphics.FONT_TINY, _prompt,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // The big value.
        var shown = (_padWidth > 0) ? _value.format("%0" + _padWidth.format("%d") + "d") : _value.format("%d");
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - numH / 2, Graphics.FONT_NUMBER_MEDIUM, shown + _suffix, Graphics.TEXT_JUSTIFY_CENTER);

        // One reminder that holding accelerates; the rest is labelled on the buttons.
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + numH / 2 + 6, Graphics.FONT_XTINY, "hold = faster",
            Graphics.TEXT_JUSTIFY_CENTER);

        // Button hints: + / - on the UP / DOWN buttons (left), action + back (right).
        drawButtonHint(dc, 0.47, false, "+", Graphics.COLOR_WHITE, true);       // timed
        drawButtonHint(dc, 0.67, false, "-", Graphics.COLOR_WHITE, true);       // timed
        drawButtonHint(dc, 0.32, true, _action, Graphics.COLOR_WHITE, true);    // timed
        drawButtonHint(dc, 0.68, true, "BACK", Graphics.COLOR_LT_GRAY, false);  // always-on
    }
}

//! Drives a NumberInputView. Single taps step once; holding UP/DOWN starts a
//! timer that repeats and accelerates. START confirms; BACK cancels (default pop).
class NumberInputDelegate extends WatchUi.BehaviorDelegate {

    private var _view as NumberInputView;
    private var _callback as Lang.Method;
    private var _timer as Timer.Timer?;
    private var _dir as Number = 0;     // current hold direction (+1 / -1)
    private var _ticks as Number = 0;   // repeats so far this hold, drives acceleration

    public function initialize(view as NumberInputView, callback as Lang.Method) {
        BehaviorDelegate.initialize();
        _view = view;
        _callback = callback;
    }

    // UP/DOWN are handled at the press/release level so we can implement hold-to-
    // repeat. Returning true consumes them (prevents the default page scroll).
    public function onKeyPressed(evt as WatchUi.KeyEvent) as Boolean {
        var k = evt.getKey();
        if (k == WatchUi.KEY_UP || k == WatchUi.KEY_DOWN) {
            _dir = (k == WatchUi.KEY_UP) ? 1 : -1;
            _ticks = 0;
            _view.bumpHints();              // keep the hints up while you're dialing
            _view.adjust(_dir, 1);          // immediate response on the first press
            WatchUi.requestUpdate();
            startRepeat();
            return true;
        }
        return false;                       // let START/BACK become onSelect/onBack
    }

    public function onKeyReleased(evt as WatchUi.KeyEvent) as Boolean {
        var k = evt.getKey();
        if (k == WatchUi.KEY_UP || k == WatchUi.KEY_DOWN) {
            stopRepeat();
            return true;
        }
        return false;
    }

    public function onSelect() as Boolean {
        stopRepeat();
        _callback.invoke(_view.getValue());
        return true;
    }

    //! Timer callback: step again, growing the multiplier the longer it's held.
    public function onTick() as Void {
        _ticks++;
        var mult = (_ticks < 5) ? 1 : ((_ticks < 15) ? 3 : 10);
        _view.adjust(_dir, mult);
        WatchUi.requestUpdate();
    }

    private function startRepeat() as Void {
        stopRepeat();
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 130, true);
    }

    private function stopRepeat() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }
}

//! Minimal delegate for terminal views (e.g. the result screen): BACK pops.
class SimpleBackDelegate extends WatchUi.BehaviorDelegate {
    public function initialize() {
        BehaviorDelegate.initialize();
    }
}

import Toybox.Application;
import Toybox.Lang;
import Toybox.Position;
import Toybox.Timer;
import Toybox.WatchUi;

//! Latest position fix, shared across views. Null until the first fix arrives.
//! Read with `$.gLastInfo`. It persists after GPS is powered down, so the compute
//! tools still have a recent "from" point (gated by hasFreshFix()).
var gLastInfo as Position.Info? = null;

//! GridRecon - GPS-denied land-navigation toolkit.
class GridReconApp extends Application.AppBase {

    // Reference count of views that need a live position, plus a short grace timer
    // so quickly passing through a menu doesn't power-cycle the receiver (a GPS cold
    // restart costs more than it saves).
    private var _gpsHolders as Number = 0;
    private var _offTimer as Timer.Timer?;
    private const GPS_GRACE_MS = 20000;

    public function initialize() {
        AppBase.initialize();
    }

    //! GPS is acquired on demand (see gpsAcquire) rather than held for the whole
    //! session, so sitting in menus/settings doesn't drain the receiver.
    public function onStart(state as Dictionary?) as Void {
    }

    public function onStop(state as Dictionary?) as Void {
        Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
        _gpsHolders = 0;
    }

    public function onPosition(info as Position.Info) as Void {
        $.gLastInfo = info;
        WatchUi.requestUpdate();
    }

    //! A position-consuming view became visible: ensure GPS is on.
    public function gpsAcquire() as Void {
        _gpsHolders++;
        if (_offTimer != null) {
            _offTimer.stop();
            _offTimer = null;
        }
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
    }

    //! A position-consuming view went away: power GPS down after a short grace period
    //! if nothing else still needs it.
    public function gpsRelease() as Void {
        if (_gpsHolders > 0) {
            _gpsHolders--;
        }
        if (_gpsHolders == 0 && _offTimer == null) {
            _offTimer = new Timer.Timer();
            _offTimer.start(method(:onGpsGrace), GPS_GRACE_MS, false);
        }
    }

    public function onGpsGrace() as Void {
        _offTimer = null;
        if (_gpsHolders == 0) {
            Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
        }
    }

    public function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var view = new $.MainView();
        return [view, new $.MainDelegate(view)];
    }
}

//! Global shims so views can manage GPS power without reaching into the app object.
function gpsAcquire() as Void {
    (Application.getApp() as GridReconApp).gpsAcquire();
}

function gpsRelease() as Void {
    (Application.getApp() as GridReconApp).gpsRelease();
}

import Toybox.Application;
import Toybox.Lang;
import Toybox.Position;
import Toybox.WatchUi;

//! Latest position fix, shared across views. Null until the first fix arrives.
//! Read with `$.gLastInfo`.
var gLastInfo as Position.Info? = null;

//! GridRecon - GPS-denied land-navigation toolkit.
class GridReconApp extends Application.AppBase {

    public function initialize() {
        AppBase.initialize();
    }

    //! Start continuous GPS. We keep the latest fix so the manual-computation
    //! tools (target location, etc.) always have a "from" point to work from.
    public function onStart(state as Dictionary?) as Void {
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
    }

    public function onStop(state as Dictionary?) as Void {
        Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
    }

    public function onPosition(info as Position.Info) as Void {
        $.gLastInfo = info;
        WatchUi.requestUpdate();
    }

    public function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var view = new $.MainView();
        return [view, new $.MainDelegate()];
    }
}

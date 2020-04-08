///Ekeh Wisdom ekeh.wisdom@gmail.com
///c2019
///Sun Nov 24 2019
library vidflux;

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';


import 'src/state/touch_notifier.dart';
import 'src/utils/connectivity_manager.dart';
import 'src/widgets/brightness_control.dart';
import 'src/widgets/error_indicator.dart';
import 'src/widgets/playpause_button.dart';
import 'src/widgets/screen_manager.dart';
import 'src/widgets/video_controls.dart';
import 'src/widgets/volume_controller.dart';



const IS_DEBUG_MODE = kDebugMode;

enum VerticalDragType { voulme, brightness, none }

enum VerticalDragDirection { up, down }

/// ```
/// A widget that plays video given the video url, this is not suitable for youtube videos see
/// youtube_player_flutter for playing youtube videos
///```
class VidFlux extends StatefulWidget {
  final bool isFullscreen;
  final VideoPlayerController videoPlayerController;

  final TouchNotifier _touchDetector;

  /// a widget to show when the video is in error state
  final Widget errorWidget;

  /// a widget to show when the video is in error state
  final Widget loadingIndicator;

  /// number of times to re initialize the video when a playback error occurs
  final int retry;

  /// if true the video automatically starts playing once initialized
  final bool autoPlay;

  /// pause and play the video on double tap;
  final bool pauseOnDoubleTap;

  ///use swipe getsture to change volume
  final bool useVolumeControls;

  ///use swipe getsture to change brightness
  final bool usebrightnessControls;

  // orientations to use when entering fullscreen mode
  final List<DeviceOrientation> fullScreenOrientations;

  // orientations to reset to  when exiting fullscreen mode
  final List<DeviceOrientation> exitOrientations;

  VidFlux({
    Key key,
    @required this.videoPlayerController,
    this.isFullscreen = false,
    this.errorWidget,
    this.loadingIndicator,
    this.retry = 5,
    this.autoPlay = false,
    this.fullScreenOrientations,
    this.pauseOnDoubleTap = true,
    this.useVolumeControls = true,
    this.usebrightnessControls = true,
    this.exitOrientations,
  })  : _touchDetector = TouchNotifier(),
        super(key: key);
  @override
  VidFluxState createState() => VidFluxState();
}

class VidFluxState extends State<VidFlux> {
  final GlobalKey<VolumeControllerState> _volumeKey = GlobalKey();
  final GlobalKey<BrightnessControllerState> _brightnessKey = GlobalKey();

  VideoPlayerController _videoPlayerController;
  bool isLoading = true;
  bool isInitializing = true;
  int retryInit;
  StateNotifier _stateNotifier;

  void _errorListener() async {
     if (!this.mounted && _videoPlayerController.value.isPlaying) {
       _videoPlayerController.play();
     }
    if (widget.videoPlayerController.value.hasError) {
      if (IS_DEBUG_MODE)
        print(
            'error listener. $retryInit   .${_videoPlayerController.value?.errorDescription}');

      if (retryInit > 0) {
        retryInit--;
        bool hasInternet = await ConnectivityManager.checkConnectivity();
        if (hasInternet) {
          _videoPlayerController?.value?.copyWith();
          if (_videoPlayerController.value?.errorDescription?.contains('404') ??
              false) {
            _stateNotifier.setLoading(false);
            _stateNotifier.setHasError(
                true, _videoPlayerController.value?.errorDescription);
            retryInit = widget.retry;
            setState(() {});
          } else
            initController();
        } else {
          _stateNotifier.setLoading(false);
          _stateNotifier.setHasError(
              true, _videoPlayerController.value?.errorDescription);
          retryInit = widget.retry;
          setState(() {});
        }
      } else {
        Scaffold.of(context).showSnackBar(SnackBar(
          content: Text(' You are not connected to the internet'),
          backgroundColor: Colors.red,
        ));
        _stateNotifier.setLoading(false);
        _stateNotifier.setHasError(
            true, ' You are not connected to the internet');
        retryInit = widget.retry;
        setState(() {});
      }
    }
  }

  @override
  void initState() {
    retryInit = widget.retry;
    _videoPlayerController = widget.videoPlayerController;
    _stateNotifier = StateNotifier();
    if (!_videoPlayerController.value.initialized) initController();
    _videoPlayerController.addListener(_errorListener);
    if (widget.autoPlay || widget.isFullscreen) _videoPlayerController.play();
    super.initState();
  }
   void disposeController() {
     _videoPlayerController.dispose();
   }
 
  void initController() {
    _stateNotifier.setLoading(true);
    _videoPlayerController?.value?.copyWith();
    _stateNotifier.setHasError(false);
    if (IS_DEBUG_MODE) print('init .........................$retryInit');

    _videoPlayerController
      ..initialize().then((_) {
        isInitializing = false;
        if (IS_DEBUG_MODE)
          print('success init .........................$retryInit');
        isLoading = false;
        _stateNotifier.setLoading(false);
        _videoPlayerController?.value?.copyWith();
        _stateNotifier.setHasError(false);
        retryInit = widget.retry;
        _videoPlayerController.play();
        // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
        setState(() {});
      });
  }

  @override
  void dispose() {
    _videoPlayerController.removeListener(_errorListener);
    ScreenManager.keepOn(false);
    super.dispose();
  }

  VerticalDragType _verticalDragType = VerticalDragType.none;
  // VerticalDragDirection _verticalDragDirection = VerticalDragDirection.down;
  double _verticalStartPosition = 0.0;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: () {
          widget._touchDetector.toggleControl();
        },
        onDoubleTap: widget.pauseOnDoubleTap
            ? () {
                widget._touchDetector.setValue(true);
                if (_videoPlayerController?.value?.isPlaying ?? false) {
                  _videoPlayerController.pause();
                } else
                  _videoPlayerController.play();
              }
            : null,
        onVerticalDragDown: (details) {
          double width = MediaQuery.of(context).size.width;
          if (details.localPosition.dx < width * .45)
            _verticalDragType = VerticalDragType.brightness;
          else if (details.localPosition.dx > width * .55)
            _verticalDragType = VerticalDragType.voulme;
          else
            _verticalDragType = VerticalDragType.none;
        },
        onVerticalDragStart: (details) {
          _verticalStartPosition = details.localPosition.dy;
        },
        onVerticalDragUpdate: (details) {
          double dragExtent = 20;
          // _verticalDragDirection = (details.delta.direction > 0)
          //     ? VerticalDragDirection.down
          //     : VerticalDragDirection.up;
          if (_verticalDragType != VerticalDragType.none) {
            double dragDistance =
                _verticalStartPosition - details.localPosition.dy;

            (_verticalDragType == VerticalDragType.voulme)
                ? _volumeKey.currentState.changeVolume(max(
                    -1.0,
                    min(dragDistance / (_verticalStartPosition * dragExtent),
                        1.0)))
                : _brightnessKey.currentState.changeBrightness(max(
                    -1.0,
                    min(dragDistance / (_verticalStartPosition * dragExtent),
                        1.0)));
          }
        },
        onVerticalDragEnd: (details) {
          _verticalDragType = VerticalDragType.none;
        },
        child: Container(
            color: Colors.black,
            child: MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (_) => widget._touchDetector),
                ChangeNotifierProvider(create: (_) => _stateNotifier)
              ],
              child: AspectRatio(
                  aspectRatio: (widget.isFullscreen &&
                          MediaQuery.of(context).orientation ==
                              Orientation.landscape)
                      ? (MediaQuery.of(context).size.width /
                          MediaQuery.of(context).size.height)
                      : _videoPlayerController.value.initialized
                          ? _videoPlayerController.value.aspectRatio
                          : 16 / 9,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      Builder(
                          builder: (context) =>
                              ScreenManagerWidget(_videoPlayerController)),
                      _videoPlayerController.value.initialized
                          ? VideoPlayer(_videoPlayerController)
                          : Container(
                              color: Colors.black,
                            ),
                      Center(child: LoadinIndicator(_videoPlayerController)),
                      if (widget.useVolumeControls)
                        VolumeController(
                          key: _volumeKey,
                        ),
                      if (widget.usebrightnessControls)
                        BrightnessController(key: _brightnessKey),
                      if (_videoPlayerController.value.initialized)
                        PlayPauseButton(
                          controller: _videoPlayerController,
                        ),
                      if (_videoPlayerController.value.initialized)
                        Container(
                            margin: EdgeInsets.only(bottom: 10),
                            alignment: Alignment.bottomCenter,
                            child: VideoControls(_videoPlayerController,
                                playerKey: widget.key,
                                fullScreenOrientations:
                                    widget.fullScreenOrientations,
                                isFullScreen: widget.isFullscreen,
                                exitOrientations: widget.exitOrientations,)),
                      widget.errorWidget ??
                          ErrorIndicator(initController: initController),
                    ],
                  )),
            )));
  }
}

class StateNotifier with ChangeNotifier {
  bool _isLoading;
  bool _hasError;
  bool takeAction;
  String message;
  Duration position;
  StateNotifier()
      : _isLoading = true,
        _hasError = false,
        takeAction = true,
        position = Duration.zero;

  get isLoading => _isLoading;
  get hasError => _hasError;
  void setHasError(bool val, [String message]) {
    _hasError = val;
    this.message = _formatMessage(message);
    notifyListeners();
  }

  void setTakeAction(bool val) {
    takeAction = val;
    notifyListeners();
  }

  void setPosition(Duration val) {
    position = val;
    notifyListeners();
  }

  void setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  String _formatMessage([String message]) {
    if (message == null) return null;
    if (message.contains('HttpDataSourceException'))
      return 'An Error occured playing video, please check your internet connection';
    if (message.contains('404'))
      return 'This Channel is not currently Streaming Please contact channel Admin';
    return 'An Error occured playing video';
  }
}

class LoadinIndicator extends StatefulWidget {
  final VideoPlayerController _controller;

  const LoadinIndicator(this._controller);
  @override
  _LoadinIndicatorState createState() => _LoadinIndicatorState();
}

class _LoadinIndicatorState extends State<LoadinIndicator> {
  bool isBuferring = true;
  Duration position = Duration.zero;
  @override
  void initState() {
    if (IS_DEBUG_MODE) print('init loader');
    widget._controller?.addListener(_buferingListener);
    // isBuferring = widget.isLoading;
    position = widget._controller?.value?.position ?? Duration.zero;
    super.initState();
  }

  @override
  void dispose() {
    widget._controller.removeListener(_buferingListener);
    super.dispose();
  }

  int _counter = 0;
  void _buferingListener() {
    // print('counter..........................$_counter');

    if (_counter > 10) {
      _counter = 0;
      if (Provider.of<StateNotifier>(context, listen: false).position ==
          widget._controller?.value?.position) {
        if (!Provider.of<StateNotifier>(context, listen: false).isLoading &&
            Provider.of<StateNotifier>(context, listen: false).takeAction)
          Provider.of<StateNotifier>(context, listen: false).setLoading(true);
        if (!(widget._controller?.value?.isPlaying ?? false))
          Provider.of<StateNotifier>(context, listen: false).setLoading(false);
      } else {
        if (Provider.of<StateNotifier>(context, listen: false).isLoading &&
            Provider.of<StateNotifier>(context, listen: false).takeAction)
          Provider.of<StateNotifier>(context, listen: false).setLoading(false);
        if (!(widget._controller?.value?.isPlaying ?? false))
          Provider.of<StateNotifier>(context, listen: false).setLoading(false);
      }
      if (Provider.of<StateNotifier>(context, listen: false).takeAction)
        Provider.of<StateNotifier>(context, listen: false)
            .setPosition(widget._controller?.value?.position);
    }
    //  if (_counter == 1)
    // Provider.of<StateNotifier>(context).setPosition(widget._controller?.value?.position);
    _counter++;
    if (widget._controller?.value?.isBuffering ?? true)
      Provider.of<StateNotifier>(context, listen: false).setLoading(true);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StateNotifier>(
        builder: (context, state, _) =>
            state._isLoading || (widget._controller?.value?.isBuffering ?? true)
                ? Container(
                    width: 70.0,
                    height: 70.0,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : SizedBox.shrink());
  }
}



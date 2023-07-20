import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'dart:developer' as d;
import 'package:audio_service/audio_service.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flip_card/flip_card_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lyric/lyrics_reader.dart';
import 'package:flutter_lyric/lyrics_reader_model.dart';
import 'package:flutter_progress_status/flutter_progress_status.dart';
import 'package:gyavun/api/image_resolution_modifier.dart';
import 'package:gyavun/components/play_button.dart';
import 'package:gyavun/components/queue_list.dart';
import 'package:gyavun/providers/media_manager.dart';
import 'package:gyavun/ui/colors.dart';
import 'package:gyavun/ui/text_styles.dart';
import 'package:gyavun/utils/downlod.dart';
import 'package:gyavun/utils/option_menu.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:iconsax/iconsax.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:provider/provider.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    this.width,
  });
  final double? width;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final PanelController controller = PanelController();

  FlipCardController flipCardController = FlipCardController();
  PanelController panelController = PanelController();
  double progress = 0;
  Uri? arturi;

  @override
  Widget build(BuildContext context) {
    MediaManager mediaManager = context.watch<MediaManager>();
    MediaItem? song = mediaManager.currentSong;
    if (arturi != song?.artUri) {
      arturi = song?.artUri;
      setState(() {});
    }

    return WillPopScope(
      onWillPop: () async {
        if (panelController.isPanelOpen) {
          panelController.close();
          return false;
        }
        return true;
      },
      child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor:
              Theme.of(context).colorScheme.surfaceTint.withAlpha(30),
          appBar: AppBar(
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            leading: Navigator.canPop(context)
                ? IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(EvaIcons.chevronDownOutline))
                : null,
            title: Text("Gyavun", style: textStyle(context, bold: false)),
            centerTitle: true,
            actions: song != null
                ? [
                    IconButton(
                        onPressed: () {
                          flipCardController.toggleCard();
                        },
                        icon: const Icon(Icons.lyrics_rounded))
                  ]
                : null,
          ),
          body: Padding(
            padding: const EdgeInsets.all(0),
            child: LayoutBuilder(builder: (context, constraints) {
              if (constraints.maxWidth > constraints.maxHeight) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ArtWork(
                      controller: flipCardController,
                      width: min(
                        constraints.maxHeight / 0.9,
                        constraints.maxWidth / 1.8,
                      ),
                      song: song,
                    ),
                    NameAndControls(
                      song: song,
                      width: constraints.maxWidth / 2,
                      height: constraints.maxHeight,
                      panelController: panelController,
                    )
                  ],
                );
              }
              return Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ArtWork(
                    controller: flipCardController,
                    width: constraints.maxWidth,
                    song: song,
                  ),
                  NameAndControls(
                    song: song,
                    width: constraints.maxWidth,
                    height: constraints.maxHeight -
                        (constraints.maxWidth * 0.85) -
                        16,
                    panelController: panelController,
                  )
                ],
              );
            }),
          )),
    );
  }
}

class ArtWork extends StatefulWidget {
  const ArtWork(
      {required this.controller,
      required this.width,
      required this.song,
      super.key});

  final FlipCardController controller;
  final MediaItem? song;
  final double width;

  @override
  State<ArtWork> createState() => _ArtWorkState();
}

class _ArtWorkState extends State<ArtWork> {
  bool fetchedLyrics = false;
  bool flipped = false;

  Map lyrMap = {};

  LyricsReaderModel? lyricsModel;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    double width = widget.width * 0.85;

    if (widget.song != null && flipped && lyrMap['id'] != widget.song?.id) {
      fetchLyrics();
    }
    return SafeArea(
      child: SizedBox(
        height: width,
        width: width,
        child: widget.song == null
            ? Icon(
                Iconsax.music,
                size: width * 0.5,
              )
            : FlipCard(
                flipOnTouch: false,
                controller: widget.controller,
                onFlipDone: (value) {
                  flipped = value;
                  setState(() {});
                  if (value && lyrMap['id'] != widget.song?.id) {
                    fetchLyrics();
                  }
                },
                front: GestureDetector(
                  onHorizontalDragEnd: (DragEndDetails details) {
                    if ((details.primaryVelocity ?? 0) > 100) {
                      context.read<MediaManager>().previous();
                    }

                    if ((details.primaryVelocity ?? 0) < -100) {
                      context.read<MediaManager>().next();
                    }
                  },
                  child: Hero(
                    tag: "playerPoster",
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: widget.song?.extras?['offline'] == true
                          ? Image.file(
                              File(widget.song?.extras!['image']),
                              width: width,
                              height: width,
                            )
                          : CachedNetworkImage(
                              imageUrl:
                                  getImageUrl(widget.song?.artUri.toString()),
                              width: width,
                              height: width,
                            ),
                    ),
                  ),
                ),
                back: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      widget.song?.extras?['offline'] == true
                          ? Image.file(
                              File(widget.song?.extras!['image']),
                              width: width,
                              height: width,
                            )
                          : CachedNetworkImage(
                              imageUrl:
                                  getImageUrl(widget.song?.artUri.toString()),
                              width: width,
                              height: width,
                            ),
                      BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black,
                              Colors.black,
                              Colors.black,
                              Colors.transparent,
                            ],
                          ).createShader(
                            Rect.fromLTRB(0, 0, bounds.width, bounds.height),
                          ),
                          blendMode: BlendMode.dstIn,
                          child: Container(
                            color: Colors.black.withOpacity(0.6),
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            width: width,
                            height: width,
                            child: fetchedLyrics
                                ? lyrMap['type'] == 'text'
                                    ? SingleChildScrollView(
                                        child: Text(
                                          '\n${lyrMap['lyrics']}\n',
                                          textAlign: TextAlign.center,
                                          style: subtitleTextStyle(context,
                                                  bold: false)
                                              .copyWith(color: Colors.white),
                                        ),
                                      )
                                    : StreamBuilder(
                                        stream: AudioService.position,
                                        builder: (context, snapshot) {
                                          return LyricsReader(
                                            position:
                                                snapshot.data?.inMilliseconds ??
                                                    0,
                                            model: lyricsModel,
                                            playing: true,
                                            lyricUi: UINetease(
                                                highlight: false,
                                                defaultSize: 19),
                                            size: Size(
                                              width,
                                              width,
                                            ),
                                          );
                                        })
                                : SizedBox(
                                    width: width,
                                    height: width,
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  fetchLyrics() {
    MediaItem song = widget.song!;
    setState(() {
      fetchedLyrics = false;
    });
    context
        .read<MediaManager>()
        .lyrics
        .getLyrics(
          id: song.id,
          title: song.title,
          artist: song.artist ?? "",
          saavnHas: song.extras?['offline'] == true
              ? false
              : bool.parse(song.extras?['has_lyrics'] ?? false),
        )
        .then((value) {
      lyrMap = value;
      lyricsModel = LyricsModelBuilder.create()
          .bindLyricToMain(lyrMap['lyrics'])
          .getModel();
      d.log(lyrMap.toString());
      setState(() {
        fetchedLyrics = true;
      });
    });
  }
}

class NameAndControls extends StatefulWidget {
  const NameAndControls(
      {required this.height,
      required this.width,
      required this.song,
      this.panelController,
      super.key});
  final double height;
  final double width;
  final MediaItem? song;
  final PanelController? panelController;

  @override
  State<NameAndControls> createState() => _NameAndControlsState();
}

class _NameAndControlsState extends State<NameAndControls> {
  @override
  Widget build(BuildContext context) {
    MediaManager mediaManager = context.watch<MediaManager>();
    return SizedBox(
      height: widget.height,
      width: widget.width,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    Hero(
                      tag: "playerTitle",
                      child: Material(
                        color: Colors.transparent,
                        child: Text(
                          widget.song?.title ?? 'Title',
                          style: bigTextStyle(context, bold: true),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    Hero(
                      tag: "playerSubtitle",
                      child: Material(
                        color: Colors.transparent,
                        child: Text(
                          widget.song?.artist ?? 'Artists',
                          style: smallTextStyle(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                  ],
                ),
                Column(
                  children: [
                    ProgressBar(
                      progress: mediaManager.progressBarState.current,
                      total: mediaManager.progressBarState.total,
                      buffered: mediaManager.progressBarState.buffered,
                      barHeight: 3,
                      thumbRadius: 5,
                      timeLabelTextStyle: smallTextStyle(context),
                      baseBarColor:
                          smallTextStyle(context).color!.withOpacity(0.3),
                      onSeek: (value) => mediaManager.seek(value),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                            onPressed: () {
                              mediaManager.shuffle();
                            },
                            icon: Icon(
                              Iconsax.shuffle,
                              color: mediaManager.isShuffleModeEnabled
                                  ? Theme.of(context).primaryColor
                                  : null,
                            )),
                        IconButton(
                            onPressed: () {
                              mediaManager.previous();
                            },
                            icon: const Icon(Iconsax.previous)),
                        const Hero(
                          tag: "playerPlayButton",
                          child: PlayButton(
                            size: 40,
                          ),
                        ),
                        IconButton(
                            onPressed: () {
                              mediaManager.next();
                            },
                            icon: const Icon(Iconsax.next)),
                        IconButton(
                          onPressed: () {
                            mediaManager.loop();
                          },
                          icon: Icon(
                            mediaManager.loopState == LoopState.off
                                ? Iconsax.repeate_music
                                : mediaManager.loopState == LoopState.all
                                    ? Iconsax.repeate_music5
                                    : Iconsax.repeate_one,
                            color: mediaManager.loopState == LoopState.off
                                ? null
                                : Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                widget.song == null
                    ? const SizedBox()
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ValueListenableBuilder(
                              valueListenable:
                                  Hive.box('downloads').listenable(),
                              builder: (context, box, child) {
                                Map? item = box.get(widget.song?.id);
                                return item != null
                                    ? item['status'] == 'pending'
                                        ? ProgressStatus(
                                            radius: 20,
                                            strokeWidth: 3,
                                            fillValue: item['progress'] * 100,
                                            fillColor: Theme.of(context)
                                                .colorScheme
                                                .inversePrimary,
                                          )
                                        : IconButton(
                                            onPressed: () {},
                                            icon:
                                                const Icon(EvaIcons.checkmark),
                                            iconSize: 30,
                                          )
                                    : IconButton(
                                        onPressed: () {
                                          download(widget.song!);
                                        },
                                        icon: const Icon(
                                            EvaIcons.downloadOutline),
                                      );
                              }),
                          StreamBuilder(
                            stream: Hive.box('favorites')
                                .watch(key: widget.song?.id),
                            builder: (context, snapshot) {
                              return IconButton(
                                onPressed: () => togglefavorite(
                                    mediaManager.currentSong!.extras!),
                                icon: Icon(
                                    isfavorite(mediaManager.currentSong!.id)
                                        ? EvaIcons.heart
                                        : EvaIcons.heartOutline),
                                iconSize: 30,
                              );
                            },
                          )
                        ],
                      ),
                const SizedBox(height: 76)
              ],
            ),
          ),
          widget.song == null
              ? const SizedBox.shrink()
              : SlidingUpPanel(
                  controller: widget.panelController,
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20)),
                  minHeight: 55 + MediaQuery.of(context).padding.bottom,
                  header: SafeArea(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20)),
                      ),
                      width: widget.width,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            height: 5,
                            width: 50,
                            decoration: BoxDecoration(
                              color: greyColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text("Next Up",
                              style: textStyle(context, bold: true)),
                        ],
                      ),
                    ),
                  ),
                  panel: QueueList(width: widget.width),
                )
        ],
      ),
    );
  }
}

Future<PaletteGenerator> getImageColor(Uri uri) async {
  return uri.toString().startsWith('http')
      ? await PaletteGenerator.fromImageProvider(NetworkImage(uri.toString()))
      : await PaletteGenerator.fromImageProvider(FileImage(File.fromUri(uri)));
}



// Container(
//                     decoration: BoxDecoration(
//                       color: Theme.of(context).scaffoldBackgroundColor,
//                       borderRadius: const BorderRadius.only(
//                           topLeft: Radius.circular(20),
//                           topRight: Radius.circular(20)),
//                     ),
//                     height: 75,
//                     width: width,
//                     child: Padding(
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 16, vertical: 16),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.center,
//                         children: [
//                           Container(
//                             height: 5,
//                             width: 50,
//                             decoration: BoxDecoration(
//                               color: greyColor,
//                               borderRadius: BorderRadius.circular(20),
//                             ),
//                           ),
//                           const SizedBox(height: 8),
//                           Text("Next Up",
//                               style: textStyle(context, bold: true)),
//                         ],
//                       ),
//                     ),
//                   ),
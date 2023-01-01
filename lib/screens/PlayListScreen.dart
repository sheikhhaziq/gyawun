import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vibe_music/Models/Track.dart';
import 'package:vibe_music/data/home1.dart';
import 'package:vibe_music/generated/l10n.dart';
import 'package:vibe_music/providers/MusicPlayer.dart';
import 'package:vibe_music/widgets/TrackTile.dart';

class PlayListScreen extends StatefulWidget {
  const PlayListScreen({required this.playlistId, super.key});
  final String playlistId;

  @override
  State<PlayListScreen> createState() => _PlayListScreenState();
}

class _PlayListScreenState extends State<PlayListScreen> {
  Map? playlist;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    HomeApi.getPlaylist(widget.playlistId).then((Map value) {
      setState(() {
        playlist = value;
        loading = false;
      });
    });
  }

  showOptions(song) {
    showCupertinoModalPopup(
        context: context,
        builder: (context) {
          return CupertinoActionSheet(
            actions: [
              Material(
                child: ListTile(
                  onTap: () {
                    Navigator.pop(context);
                    context.read<MusicPlayer>().addToQUeue(song);
                  },
                  title: Text(
                    S.of(context).addToQueue,
                    style: Theme.of(context)
                        .primaryTextTheme
                        .titleMedium
                        ?.copyWith(
                            overflow: TextOverflow.ellipsis, fontSize: 16),
                  ),
                ),
              )
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      body: SafeArea(
        child: playlist == null || loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: CachedNetworkImage(
                              imageUrl: playlist?['thumbnails'][
                                  (playlist?['thumbnails'].length / 2)
                                      .floor()]['url'],
                              width: (size.width / 2) - 24,
                              height: (size.width / 2) - 24,
                              errorWidget: ((context, error, stackTrace) {
                                return Image.asset(
                                  "assets/images/playlist.png",
                                  width: (size.width / 2) - 24,
                                  height: (size.width / 2) - 24,
                                );
                              }),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    playlist?['title'],
                                    style: Theme.of(context)
                                        .primaryTextTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                  Text(
                                    '${playlist?['tracks'].length} ${S.of(context).Songs}',
                                    style: Theme.of(context)
                                        .primaryTextTheme
                                        .bodyMedium,
                                  ),
                                  Text(
                                    playlist?['author']['name'],
                                    style: Theme.of(context)
                                        .primaryTextTheme
                                        .bodyMedium,
                                  ),
                                  MaterialButton(
                                    textColor: Colors.white,
                                    color: Colors.black,
                                    onPressed: () async {
                                      await context
                                          .read<MusicPlayer>()
                                          .addPlayList(
                                            playlist?['tracks'],
                                          );
                                    },
                                    child: Text(S.of(context).Play_All),
                                  ),
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 16),
                      child: Text(
                        S.of(context).Tracks,
                        style: Theme.of(context)
                            .primaryTextTheme
                            .bodyMedium
                            ?.copyWith(
                                fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                    ),
                    if (playlist != null)
                      ListView.builder(
                          shrinkWrap: true,
                          primary: false,
                          itemCount: playlist?['tracks'].length,
                          itemBuilder: (context, index) {
                            Map<String, dynamic> track =
                                playlist?['tracks'][index];
                            if (track['videoId'] == null) {
                              playlist?['tracks'].remove(track);
                              setState(() {});
                              return const SizedBox.shrink();
                            }

                            return TrackTile(
                              track: track,
                            );
                          }),
                  ],
                ),
              ),
      ),
    );
  }
}

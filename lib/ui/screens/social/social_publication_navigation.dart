import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sophis/models/social/social_snapshot.dart';
import 'package:sophis/providers/social_provider.dart';
import 'package:sophis/ui/screens/social/people_screen.dart';
import 'package:sophis/ui/screens/social/social_publish_screen.dart';
import 'package:sophis/ui/theme/app_theme.dart';

Future<void> openSocialPublication({
  required BuildContext context,
  required SocialSnapshot Function() snapshot,
  required bool isRecipe,
}) async {
  final social = context.read<SocialProvider>();
  if (social.profile == null) {
    await Navigator.push(context, AppTheme.slideRoute(const PeopleScreen()));
  }
  if (!context.mounted || social.profile == null) return;
  try {
    await Navigator.push(
      context,
      AppTheme.slideRoute(
        SocialPublishScreen(snapshot: snapshot(), isRecipe: isRecipe),
      ),
    );
  } on FormatException {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This meal needs valid items and portions before it can be shared.',
          ),
        ),
      );
    }
  }
}

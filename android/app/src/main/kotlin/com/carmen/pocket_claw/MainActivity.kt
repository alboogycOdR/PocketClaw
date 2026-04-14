package com.carmen.pocket_claw

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (not FlutterActivity) is required by the
// local_auth plugin — the biometric prompt is implemented as an
// androidx.fragment.app.DialogFragment and needs a FragmentActivity
// host. FlutterFragmentActivity is Flutter's official subclass of it
// and is drop-in compatible with the normal FlutterActivity.
class MainActivity : FlutterFragmentActivity()

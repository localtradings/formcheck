package com.localtradings.formcheck

import com.google.firebase.appcheck.AppCheckProviderFactory
import com.google.firebase.appcheck.debug.DebugAppCheckProviderFactory

internal fun coachAppCheck(): AppCheckProviderFactory =
    DebugAppCheckProviderFactory.getInstance()

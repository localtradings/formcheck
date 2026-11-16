package com.localtradings.formcheck

import com.google.firebase.appcheck.AppCheckProviderFactory
import com.google.firebase.appcheck.playintegrity.PlayIntegrityAppCheckProviderFactory

internal fun coachAppCheck(): AppCheckProviderFactory =
    PlayIntegrityAppCheckProviderFactory.getInstance()

// Stuff used to track the specific jobs in this app
List<CompletionStatus> imageUpdateStatus = new List(9);
List<CompletionStatus> legendUpdateStatus = new List(9);
CompletionStatus notificationPreferencesLoaded = CompletionStatus.inactive;
CompletionStatus savedPlacesLoaded = CompletionStatus.inactive;
CompletionStatus forecastCacheLoaded = CompletionStatus.inactive;
CompletionStatus lastKnownLocationLoaded = CompletionStatus.inactive;
List<CompletionStatus> loadStatus = [savedPlacesLoaded, forecastCacheLoaded, notificationPreferencesLoaded, lastKnownLocationLoaded];

// Generic stuff that can be reused (definitions, helper functions, etc)
// Global array and enum definition used to track status of jobs for each image
enum CompletionStatus {
  success, // "cold" states
  unnecessary, 
  timedOut,
  failure,
  inactive,
  inProgress, // "hot" states
  isQueued, // either being processed or will be soon
}

bool isHotState(dynamic element) {
  if (element == CompletionStatus.isQueued || element == CompletionStatus.inProgress) {
    return true;
  } else {
    return false;
  }
}

bool isSuccess(dynamic element) {
  if (element == CompletionStatus.success) {
    return true;
  } else {
    return false;
  }
}

bool isUnnecessary(dynamic element) {
  if (element == CompletionStatus.unnecessary) {
    return true;
  } else {
    return false;
  }
}

bool isSuccessOrUnnecessary(dynamic element) {
  if (element == CompletionStatus.success || element == CompletionStatus.unnecessary) {
    return true;
  } else {
    return false;
  }
}

setAll(List<CompletionStatus> list, CompletionStatus newValue) {
  for (CompletionStatus item in list) {
    item = newValue;
  }
}

Future<CompletionStatus> completion(List<CompletionStatus> statusList, {Duration interval = const Duration(milliseconds: 250), int counter = 0, int maxTries = 60}) async {
  // All the garbage we use to determine when the job is actually done
  // and give feedback to the user.
  while(true) {
    // Every 500 ms proceed to check to see if any ending condition is true.
    await Future.delayed(interval);
    // Check to see if we have exceeded the max waiting time.
    if (counter >= maxTries) {
      return CompletionStatus.timedOut;
    }
    if (statusList.every(isSuccess)) {
      // Then the update has fully succeeded.
      return CompletionStatus.success;
    } else if (statusList.contains(CompletionStatus.failure)) {
      // Then we know the update has failed somewhere.
      return CompletionStatus.failure;
    } else if (statusList.every(isUnnecessary)) {
      // Then the update was not necessary. Tell the user so.
      return CompletionStatus.unnecessary;
    } else if (statusList.every(isSuccessOrUnnecessary)) {
      // Perhaps we have a mix of only success and unnecessary. In this case, just display to the user as a success.
      return CompletionStatus.success;
    } else {
      // Otherwise continue to wait until any of the above situations is true,
      // or we time out.
      counter += 1;
    }
  }
}
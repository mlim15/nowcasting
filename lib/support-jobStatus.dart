import 'package:flutter/foundation.dart';

// Stuff used to track the specific jobs in this app
List<CompletionStatus> imageUpdateStatus = new List(9);
List<CompletionStatus> legendUpdateStatus = new List(9);
CompletionStatus notificationPreferencesLoaded = CompletionStatus.notStarted;
CompletionStatus savedPlacesLoaded = CompletionStatus.notStarted;
CompletionStatus forecastCacheLoaded = CompletionStatus.notStarted;
CompletionStatus lastKnownLocationLoaded = CompletionStatus.notStarted;
List<CompletionStatus> loadStatus = [savedPlacesLoaded, forecastCacheLoaded, notificationPreferencesLoaded, lastKnownLocationLoaded];

final Job singleImageUpdate = Job();

//final Job completeImageUpdate = Job( () {
//    job.imageUpdateStatus[index] = job.completionStatus.inProgress;
//    try {
//      // First check for remote update for the image and download it if necessary.
//      if (await remoteImage(forceRefresh, index)) {
//        // If an update occurred, then also update its legend and clear its cache.
//        imagery.forecastCache[index].clear();
//        await legend(index);
//        job.imageUpdateStatus[index] = job.completionStatus.success;
//        return true;
//      } else {
//        // No update was needed for the image.
//        job.imageUpdateStatus[index] = job.completionStatus.unnecessary;
//        return false;
//      }
//    } catch(e) {
//      print('update.completeUpdateSingleImage: Error updating image $index: '+e.toString());
//      job.imageUpdateStatus[index] = job.completionStatus.failure;
//      return false;
//    }
//  }
//  ).addChildXForEachY();

// Generic stuff that can be reused (definitions, helper functions, etc)
// Global array and enum definition used to track status of jobs for each image
class Job {
  CompletionStatus status = CompletionStatus.notStarted;
  Function<CompletionStatus>([List<dynamic>]) task;
  List<Job> children;
  Iterable childIterable;
  bool isBlocking;

  // Constructor
  Job(this.task, this.isBlocking);

  // Helpers
  addChild(Job newChild) {
    children.add(newChild);
  }

  addChildXForEachY(Job childToAdd, Iterable list) {
    for (dynamic item in list) {
      this.addChild(childToAdd);
    }
  }

  bool hasChildren() {
    if (this.children.isEmpty) {
      return false;
    } else {
      return true;
    }
  }

  setStatus(CompletionStatus newStatus) {
    this.status = newStatus;
  }

  Future<CompletionStatus> run() async {
    // If the job is already in progress, don't run, just return.
    if (isInProgress(this.status)) {return CompletionStatus.inProgress;}
    // Otherwise, start the job.
    this.status = CompletionStatus.inProgress;
    if (this.hasChildren()) {
      for (Job child in children) {
        if (child.isBlocking) {
          CompletionStatus childResult = await child.run();
          if (!isSuccessOrUnnecessary(childResult)) {
            // Child failure results in parent failure
            return CompletionStatus.failure;
          }
        } else {
          child.run();
        }
      }
    }
    this.status = await this.task();
    return this.status;
  }

}

enum CompletionStatus {
  success,
  unnecessary,
  failure,
  inProgress,
  notStarted,
  timedOut
}

bool isInProgress(dynamic element) {
  if (element == CompletionStatus.inProgress) {
    return true;
  } else {
    return false;
  }
}

bool containsInProgress(List list) {
  if (list.any((item) {return item == CompletionStatus.inProgress;})) {
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

// Theoretically this method will not be necessary once jobs are a thing
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

handleCompletion({@required CompletionStatus statusOfResult, Function successCallback, Function failureCallback, Function unnecessaryCallback, Function timedOutCallback}) {
  if (statusOfResult == CompletionStatus.timedOut && timedOutCallback != null) {
    timedOutCallback();
    return;
  } else if (statusOfResult == CompletionStatus.success && successCallback != null) {
    successCallback();
    return;
  } else if (statusOfResult == CompletionStatus.failure && failureCallback!= null) {
    failureCallback();
    return;
  } else if (statusOfResult == CompletionStatus.unnecessary && unnecessaryCallback != null) {
    unnecessaryCallback();
    return;
  } else {
    throw('job.handleCompletion: A way to handle the job status recieved was not implemented.');
  }
}
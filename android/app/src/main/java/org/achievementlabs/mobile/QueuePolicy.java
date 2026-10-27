package org.achievementlabs.mobile;
final class QueuePolicy {
 static int action(String status,boolean stop){return pendingVerification(status)?1:review(status)&&stop?2:status.equals("Waiting")?0:3;}
 static boolean review(String s){return s.startsWith("Failed")||s.startsWith("Interrupted")||s.startsWith("Unconfirmed")||s.startsWith("Needs review");}
 static boolean pendingVerification(String s){return s.startsWith("Accepted")||s.startsWith("Verifying")||s.startsWith("Unconfirmed")||s.startsWith("Interrupted")||s.equals("Submitting");}
 static boolean terminal(String s){return s.startsWith("Already unlocked")||s.startsWith("Confirmed")||s.equals("Skipped by user");}
 static boolean transientFailure(Exception e){return e instanceof java.io.IOException || e instanceof Net.HttpFailure&&(((Net.HttpFailure)e).status>=500||((Net.HttpFailure)e).status==408);}
}

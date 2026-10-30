package org.achievementlabs.mobile;
import org.json.*;
import java.util.function.BooleanSupplier;
final class QueueVerification {
 interface Reader { JSONObject read() throws Exception; }
 interface Sleeper { void sleep(long millis) throws InterruptedException; }
 static final class Result {final boolean confirmed;final String progress;Result(boolean c,String p){confirmed=c;progress=p;}}
 static Result watch(Reader read,BooleanSupplier allowed,Sleeper sleep,java.util.function.Consumer<String> progress)throws Exception{
  while(true){
   Result result=verify(read,allowed,sleep);
   if(result.confirmed)return result;
   progress.accept(result.progress);
   if(Thread.currentThread().isInterrupted()||!allowed.getAsBoolean())throw new InterruptedException();
   sleep.sleep(30000);
  }
 }
 static Result verify(Reader read,BooleanSupplier allowed,Sleeper sleep)throws Exception{
  String progress="Xbox progress unavailable";long end=System.nanoTime()+45_000_000_000L;
  for(long wait:new long[]{0,2000,4000,8000,12000}){
   if(Thread.currentThread().isInterrupted()||!allowed.getAsBoolean())throw new InterruptedException();
   if(System.nanoTime()>=end)break;
   if(wait>0)sleep.sleep(wait);
   if(Thread.currentThread().isInterrupted()||!allowed.getAsBoolean())throw new InterruptedException();
   JSONObject row=read.read();
   if(Thread.currentThread().isInterrupted()||!allowed.getAsBoolean())throw new InterruptedException();
   if(row==null)continue;
   JSONArray req=row.optJSONObject("progression")==null?null:row.getJSONObject("progression").optJSONArray("requirements");
   java.util.List<String> counters=new java.util.ArrayList<>();
   if(req!=null)for(int i=0;i<Math.min(10,req.length());i++){JSONObject r=req.optJSONObject(i);if(r!=null)counters.add(number(r.optString("current"))+"/"+number(r.optString("target")));}
   progress=counters.isEmpty()?"Xbox state: "+("Achieved".equalsIgnoreCase(row.optString("progressState"))?"Achieved":"not confirmed"):"Xbox progress: "+String.join(", ",counters);
   if("Achieved".equalsIgnoreCase(row.optString("progressState")))return new Result(true,progress);
  }
  return new Result(false,progress);
 }
 static String number(String s){try{double v=Double.parseDouble(s);return Double.isFinite(v)?s:"?";}catch(Exception e){return "?";}}
}

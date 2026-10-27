package org.achievementlabs.mobile;

import android.content.Intent;
import androidx.test.platform.app.InstrumentationRegistry;
import org.junit.Before;
import org.junit.After;
import org.junit.Test;
import static org.junit.Assert.*;
import android.view.accessibility.AccessibilityNodeInfo;
import android.accessibilityservice.AccessibilityServiceInfo;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;

/** Exercises the real WebView dialogs using synthetic offline data only. */
public final class ConfirmationDialogsTest {
 private MainActivity activity;
 private android.app.Instrumentation getInstrumentation(){return InstrumentationRegistry.getInstrumentation();}
 @Before public void setUp() throws Exception {
  Intent intent=new Intent(getInstrumentation().getTargetContext(),MainActivity.class);
  intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK|Intent.FLAG_ACTIVITY_CLEAR_TASK);
  intent.putExtra("preview",true).putExtra("page","settings");
  activity=(MainActivity)getInstrumentation().startActivitySync(intent);
  assertTrue(activity.engine.preview);
  getInstrumentation().runOnMainSync(()->{try{activity.engine.fixture();}catch(Exception e){throw new RuntimeException(e);}});
  AccessibilityServiceInfo info=getInstrumentation().getUiAutomation().getServiceInfo();
  info.flags|=AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS;
  getInstrumentation().getUiAutomation().setServiceInfo(info);
  waitFor("typeof state!=='undefined' && !!state.account && !busy");
 }
 @After public void tearDown() throws Exception {
  if(activity!=null)getInstrumentation().runOnMainSync(()->activity.finish());
 }
 private void script(String js){getInstrumentation().runOnMainSync(()->activity.web.evaluateJavascript(js,null));}
 private String evaluate(String js)throws Exception{
  AtomicReference<String> result=new AtomicReference<>();CountDownLatch done=new CountDownLatch(1);
  getInstrumentation().runOnMainSync(()->activity.web.evaluateJavascript(js,value->{result.set(value);done.countDown();}));
  assertTrue("WebView evaluation timed out",done.await(10,TimeUnit.SECONDS));return result.get();
 }
 private void waitFor(String js)throws Exception{
  long until=System.currentTimeMillis()+15000;
  while(System.currentTimeMillis()<until){if("true".equals(evaluate("Boolean("+js+")")))return;Thread.sleep(100);}
  fail("WebView condition timed out: "+js);
 }
 private void answer(boolean accept)throws Exception{
  String id=accept?"android:id/button1":"android:id/button2";
  long until=System.currentTimeMillis()+10000;
  while(System.currentTimeMillis()<until){
   AccessibilityNodeInfo root=getInstrumentation().getUiAutomation().getRootInActiveWindow();
   if(root!=null){List<AccessibilityNodeInfo> buttons=root.findAccessibilityNodeInfosByViewId(id);
    for(AccessibilityNodeInfo button:buttons)if(button.isVisibleToUser()){
     assertTrue("Could not answer confirmation",button.performAction(AccessibilityNodeInfo.ACTION_CLICK));return;
    }
   }
   Thread.sleep(100);
  }
  fail("Confirmation dialog did not appear; action must not silently cancel");
 }
 @Test public void testDisconnectCancelThenConfirm()throws Exception{
  script("window.__testActions=[];run=async(a,p)=>{window.__testActions.push(a);return {}};page='settings';settingsTab='Account';render();document.querySelector('[data-action=disconnect]').click()");
  answer(false);assertEquals("0",evaluate("window.__testActions.length"));assertNotNull(activity.engine.account);
  script("document.querySelector('[data-action=disconnect]').click()");answer(true);
  waitFor("window.__testActions.length===1");
  assertEquals("\"disconnect\"",evaluate("window.__testActions[0]"));
 }
 @Test public void testDisconnectClearsStoredAccountAndKeepsSavedQueue()throws Exception{
  // An isolated synthetic store exercises the real disconnect without weakening preview mode.
  final java.io.File files=new java.io.File(activity.getCacheDir(),"confirmation-native-tests");
  assertTrue(files.isDirectory()||files.mkdirs());
  android.content.Context isolatedContext=new android.content.ContextWrapper(activity){
   @Override public android.content.Context getApplicationContext(){return this;}
   @Override public java.io.File getFilesDir(){return files;}
  };
  SessionEngine isolated=new SessionEngine(isolatedContext,true,"queue");
  assertTrue(isolated.preview);assertNotNull(isolated.account);assertEquals(1,isolated.queue.length());
  isolated.preview=false;
  try{
   isolated.handle("disconnect",new org.json.JSONObject());
   assertNull(isolated.account);
   org.json.JSONObject saved=isolated.vault.read();
   assertFalse(saved.has("account"));assertEquals(1,saved.getJSONObject("queues").getJSONArray("0").length());
  }finally{isolated.work.shutdownNow();isolated.sessions.shutdownNow();}
 }
 @Test public void testUnlockCancelThenConfirmDoesNotSendLiveRequests()throws Exception{
  // Intercept after the real action/confirmation handler so Xbox is never contacted.
  script("game={titleId:'7'};selected=new Set(['1','2']);window.__testActions=[];run=async(a,p)=>{window.__testActions.push({action:a,ids:p.ids});return {}};document.body.insertAdjacentHTML('beforeend','<button id=confirm-unlock data-action=unlockSelected>Unlock selected</button>');document.getElementById('confirm-unlock').click()");
  answer(false);assertEquals("0",evaluate("window.__testActions.length"));
  script("document.getElementById('confirm-unlock').click()");answer(true);
  waitFor("window.__testActions.length===1");
  assertEquals("\"unlock\"",evaluate("window.__testActions[0].action"));
  assertEquals("2",evaluate("window.__testActions[0].ids.length"));
 }
}

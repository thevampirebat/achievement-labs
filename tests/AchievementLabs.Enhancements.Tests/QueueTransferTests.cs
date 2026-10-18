using AchievementLabs.Core;
using Newtonsoft.Json;
public static class QueueTransferTests
{
 public static void Run()
 {
  var value=new QueueTransfer { OwnerXuid="42",Games=[new TransferGame { TitleId="7",Name="Game",Items=[new TransferAchievement { AchievementId="1",Name="Example",DelaySeconds=120,RemainingDelaySeconds=23 }] }] };
  var text=JsonConvert.SerializeObject(value);var restored=QueueTransfer.Parse(text,"42");
  if(restored.Games[0].Items[0].RemainingDelaySeconds!=23||text.Contains("authorization"))throw new Exception("Portable queue round trip failed");
  bool rejected=false;try{QueueTransfer.Parse(text,"43");}catch(System.IO.InvalidDataException){rejected=true;}if(!rejected)throw new Exception("Wrong account accepted");
  restored.Games[0].Items[0].DelaySeconds=-1;rejected=false;try{restored.Validate("42");}catch(System.IO.InvalidDataException){rejected=true;}if(!rejected)throw new Exception("Invalid delay accepted");
  Console.WriteLine("PASS: portable queue format, remaining delay, account validation and invalid-delay rejection. No network.");
 }
}

#require "utilities.lib.nut:3.0.0"

@set APPNAME = "GuardedProcessQueue Library Device Test"
@set VERSIONMAJOR = 2
@set VERSIONMINOR = 2
@set VERSIONUPDATE = 0
@set LOGFRAME = "light"

@include once "github:vedecoid/SquirrelLib_Tools/VdcLogging.nut@master"
@include "github:vedecoid/SquirrelLib_Tools/VdcDefaultFileHeader.nut@master" 
@include once "github:vedecoid/SquirrelLib_Tools/VdcUtilities.lib.nut@master" 
@include once "github:vedecoid/SquirrelLib_Tools/VdcDebug.lib.nut@master" 

@include "..\\src\\GuardedProcessQueue.lib.nut"
gShowall <- true;
testProcess <- GuardedProcessQueue("Test",eQueueType.fifo,2,3,30);

testProcess.onProcess(function(element){
    server.log("Executing generic handler on " + element);
    imp.wakeup(2,function(){
    	testProcess.NotifyReady("It's done");
    	});
});

testProcess.onReady(function(element,result,retrycnt) {
	server.log("Executing ready handler with result " + result + ": after " + retrycnt + " retries with " + testProcess.ElementsWaiting() + " waiting in queue");  });

testProcess.onTimeout(function(element,timeoutperiod,retrycnt) {
	server.log("Executing timeout handler after " + timeoutperiod + " secs and " + retrycnt + " retries");  });

testProcess.onMaxretries(function(element,retrycnt) {
	server.log("Executing maxretries handler after " + retrycnt + " retries");  });
testProcess.onException(function(element,state,e) {
	server.log("Executing exception handler at state  " + state +  " with exception : " + e);  });
testProcess.onMaxElements(function(item) {
	server.log("Executing max element handler on " + item  );  });


testProcess.StartProcessing();

globalcnt <- 0;

// repetitive injection of an element to process
function injectElement()
{

	for (local i = 0; i < 25; i++)
	{
	  server.log(format("Inserting Element %d in processing queue",globalcnt ));

/**** SPECIFIC HANDLERS  TEST ***************************/

/*			testProcess.SendToBack("even",
				format("Even Element %d",globalcnt++),
				function(element) {

			    server.log("Executing specific processing handler [" + element + "] on " + element); 
			    imp.wakeup(0.1,function()
			    	{
			    		server.log("Notifying Ready ...");
			    		testProcess.NotifyReady("It's done locally")})},
			  function(element,result,retrycnt){
			  	server.log("Executing specific ready handler [" + element.e + "] with result :" + result + " after " + retrycnt + " retries"); 
			  	});*/


/**** GENERIC HANDLERS  TEST ***************************/

/*			testProcess.SendToBack("odd",format("Odd Element %d",globalcnt++),null,null);*/

/**** ERRORNOTIFICATION TEST ***************************/

/*			testProcess.SendToBack("even",
				format("Even Element %d",globalcnt++),
				function(element) {

			    server.log("Executing specific processing handler [" + element + "] on " + element); 
			    imp.wakeup(0.2,function()
			    	{
			    		server.log("Notifying Error ...");
			    		testProcess.NotifyError("Error in reception")})},
			  	null);


	}
*/
	/**** ERRORNOTIFICATION TEST ***************************/

			testProcess.SendToBack("even",
				format("Even Element %d",globalcnt++),
				function(element) {

			    server.log("Executing specific processing handler [" + element + "] on " + element); 
			    imp.wakeup(0.2,function()
			    	{
			    		server.log("Notifying timeout ...");
			    		testProcess.NotifyTimeout("Timeout in reception")})},
			  	null);


	}
	imp.wakeup(10,injectElement);		
}

injectElement();
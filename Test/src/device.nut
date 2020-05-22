#require "utilities.lib.nut:3.0.1"

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

// constructor(name, type, maxprocessingtimeout , maxretries,maxelements)
testProcess <- GuardedProcessQueue("Test",eQueueType.fifo,10,3,10);

testProcess.onProcess(function(entry){
    server.log("[Generic handler] Executing processing handler on entry with reference " + entry._reference);
    imp.wakeup(2,function(){
    	testProcess.NotifyProcessingReady("It's done");
    	});
});

testProcess.onReady(function(entry,result,retrycnt) {
	server.log("[Generic handler] Executing ready handler with result " + result + ": after " + retrycnt + " retries with " + testProcess.ElementsWaiting() + " waiting in queue");  });

testProcess.onProcessingTimeout(function(entry,retrycnt) {
	server.log("[Generic handler] Executing timeout handler after " + entry._timeout + " secs and " + retrycnt + " retries");  });

testProcess.onMaxretries(function(entry,retrycnt) {
	server.log("[Generic handler] Executing maxretries handler after " + retrycnt + " retries");  });

testProcess.onException(function(entry,state,e) {
	server.log("[Generic handler] Executing exception handler at state  " + state +  " with exception : " + e);  });

testProcess.onMaxElements(function(entry) {
	server.log("[Generic handler] Executing max element handler on " + entry._reference  );  });


testProcess.StartProcessing();

globalcnt <- 0;

// repetitive injection of an element to process
function injectElement()
{

	for (local i = 0; i < 5; i++)
	{
	  server.log(format("Inserting Element %d in processing queue",globalcnt ));

/**** SPECIFIC HANDLERS  TEST ***************************/

			testProcess.SendToBack(utilities.getNewUUID(),									// reference
				format("Even Element %d",globalcnt++),	// element
				function(entry) 
				{											// processinghandler
			    server.log("[Specific handler] Executing processing handler [" + entry._data + "] for item  with timeout " + entry._timeout ); 
			    local readywakeup = imp.wakeup(0.5,function()	
			    {
			    	server.log("Notifying Ready ...");	
			    	testProcess.NotifyProcessingReady(format("It's done locally for entry with reference %s",entry._reference));
			    }.bindenv(this));
			  }.bindenv(this),
			  function(entry,result,retries) 
			  {
			  	server.log(format("[Specific handler] Processing ready for entry with reference %s and result %s after %d retries",entry._reference,result,retries));
			  },			// no ready handler for this test
			  5 );			// timeout

/**** GENERIC HANDLERS  TEST ***************************/

/*			testProcess.SendToBack("odd",format("Odd Element %d",globalcnt++),null,null);*/

/**** ERROR NOTIFICATION TEST ***************************/
/*			testProcess.SendToBack(utilities.getNewUUID(),									// reference
				format("Even Element %d",globalcnt++),	// element
				function(entry) 
				{											// processinghandler
			    server.log("[Specific handler] Executing processing handler [" + entry._data + "] for item  with timeout " + entry._timeout ); 
			    imp.wakeup(4,function()	
			    {
			    	server.log("Notifying Error ...");	
			    	testProcess.NotifyProcessingError(format("Error processing for entry with reference %s",entry._reference));
			    }.bindenv(this));
			  }.bindenv(this),
			  function(entry,result,retries) 
			  {
			  	server.log(format("[Specific handler] Processing ready for entry with reference %s and result %s after %d retries",entry._reference,result,retries));
			  },			// no ready handler for this test
			  5 );			// timeout*/

	/**** TIMEOUT NOTIFICATION TEST ***************************/

/*			testProcess.SendToBack(utilities.getNewUUID(),									// reference
				format("Even Element %d",globalcnt++),	// element
				function(entry) 
				{											// processinghandler
			    server.log("[Specific handler] Executing processing handler [" + entry._data + "] for item  with timeout " + entry._timeout ); 
			    imp.wakeup(entry._timeout,function()	
			    {
			    	server.log("Notifying Timeout ...");	
			    	testProcess.NotifyProcessingTimeout(entry._timeout);
			    }.bindenv(this));
			  }.bindenv(this),
			  function(entry,result,retries) 
			  {
			  	server.log(format("[Specific handler] Processing ready for entry with reference %s and result %s after %d retries",entry._reference,result,retries));
			  },			// no ready handler for this test
			  5 );			// timeout*/


	}
	//imp.wakeup(10,injectElement);		
}

injectElement();
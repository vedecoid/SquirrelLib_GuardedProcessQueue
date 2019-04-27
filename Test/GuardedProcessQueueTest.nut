#require "Bullwinkle.class.nut:2.3.2"
/*************************************************************************
Project   : GuardedProcessQueueTest.pnut
Source    : GuardedProcessQueueTest.nut
Date      : 9/07/2018 2:53:11
Version   : 0.0.1
Build     : 19
Copyright : (c)2018 Verhaegen Development Company
*************************************************************************/

// Boot device information functions
// By Tony Smith
// Licence: MIT
// Code version 1.0.1
function bootMessage() {
    // Present OS version and network connection information
    // Take the software version string and extract the version number
    local a = split(imp.getsoftwareversion(), " - ");
	server.log("impOS version " + a[2]);

	// Get current networking information
	local i = imp.net.info();

	// Get the active network interface (or the first network on
	// the list if there is not network marked as active)
	local w = i.interface[i.active != null ? i.active : 0];

	// Get the SSID of the network the device is connected to
	// (or fallback to the last known network)
	local s = w.type == "wifi" ? ("connectedssid" in w? w.connectedssid : w.ssid) : "";

	// Get the type of network we are using (WiFi or Ethernet)
	local t = "Connected by " + (w.type == "wifi" ? "WiFi on SSID \"" + s + "\"" : "Ethernet");
	server.log(t + " with IP address " + i.ipv4.address);

	// Present the reason for the start-up
	s = logWokenReason();
	if (s.len() > 0) server.log(s);
}

function logWokenReason()
{
	// Return the recorded reason for the device’s start-up
	local reason = "";
	local causes = ["Cold boot", "Woken after sleep", "Software reset", "Wakeup pin triggered",
	"Application code updated", "Squirrel error during the last run"
      
	"This device has a new impOS", "Woken by a snooze-and-retry event",
	"imp003 Reset pin triggered", "This device has just been re-configured",
	"Restarted by server.restart()"];
	try
	{
	    reason = "Device restarted: " + causes[hardware.wakereason()];
	}
	catch (err)
	{
	    reason = "Device restarted: Reason unknown";
	}

	return reason;
}
const APPNAME = "GuardedProcessQueueTest";
const BUILDDATE = "9/07/2018 2:53:11";
const VERSIONMAJOR = 0
const VERSIONMINOR = 0
const VERSIONUPDATE = 1
const BUILDNR = 19
const BUILDNRSTR = "19";
const VERSIONSTR = "0.0.1";
const RELEASESTR = "alpha";
server.log("***********************************************************");
server.log(format("Application :%s ",APPNAME));
server.log(format("Version : %s-%s",VERSIONSTR,RELEASESTR));
server.log(format("Build : %s (%s)",BUILDNRSTR,BUILDDATE));
server.log(format("Module Type : %s",imp.info().type));
server.log(format("Id/Url: %s",(imp.environment() == ENVIRONMENT_AGENT) ? http.agenturl() : hardware.getdeviceid()));
if (imp.environment() != ENVIRONMENT_AGENT) {
  bootMessage();
  }
server.log("***********************************************************");
server.log("");

/*************************************************************************
#include "..\..\..\Classes2_0\Tools\Utilities.ston.nut"
*************************************************************************/
enum TableCompare {
	DataEmpty,
	ModelEmpty,
	DataInModel,
	ModelInData,
	Identical
}

lib <- {

	partner = null
	partnerstr = ""
	selfstr = ""

	function is_agent() {
    return (imp.environment() == ENVIRONMENT_AGENT);
	}

	function is_card001() {
		    return (imp.environment() == ENVIRONMENT_CARD);
	}

	function is_module002() {
			if (imp.environment() == ENVIRONMENT_MODULE)
				if  (!("pinW" in hardware))
					return true;
			return false;
	}

	function is_module003() {
			if (imp.environment() == ENVIRONMENT_MODULE)
				if  ("pinW" in hardware)
					return true;
			return false;
	}

	function init() {
		partner  = is_agent() ? device : agent;
		partnerstr = is_agent() ? "device" : "agent";
		selfstr = is_agent() ? "agent" : "device";
	}

	function reboot() {
		server.restart();
	}

	function isNullOrEmpty(object)
	{
		if (object == null) return true;
		if ((typeof(object) == "string") && (object == "")) return true;
		if ((typeof(object) == "table") && (object.len() == 0)) return true;
		if ((typeof(object) == "array") && (object.len() == 0)) return true;
		return false;
	}

	function isNullOrZero(object)
	{
		if (object == null) return true;
		if (object == 0) return true;
		return false;
	}

	function string_to_blob(str) {
    local myBlob = blob(str.len());
    for(local i = 0; i < str.len(); i++) {
        myBlob.writen(str[i],'b');
    }
    myBlob.seek(0,'b');
    return myBlob;
	}

	function timestamp() {
    if (is_agent()) {
        local d = date();
        return format("%d.%06d", d.time, d.usec);
    } else {
        local d = math.abs(hardware.micros());
        return format("%d.%06d", d/1000000, d%1000000);
    }
	}

	// platform independent timer that can provide msec accuracy for at least 24hrs without overflow
	// can only be used for relative time comparisons ie within one platform
	function relmsecs()
	{
		local msec;
    if (is_agent()) {
			local d = date();
        msec = d.hour*3600000+d.min*60000+d.sec*1000+d.usec/1000;
    } else {
        msec = math.abs(hardware.millis());
    }
		return msec;
	}

	function byteArrayString(arr){
        local str = ""
        for(local i = 0; i < arr.len(); i++){
            if(arr[i] == null) break;
            str = str + format("%.2X", arr[i]);
        }
        return str;
	}

//Takes a numeric hex (0x1234) or int value and returns a string len bytes long with hex values
	function hexConvert(val, len){   
			return format("%." + (len*2) + "X", val)
	}


// Parses a hex string and turns it into an integer
	function hextoint(str) {
    if (typeof str == "integer") {
        if (str >= '0' && str <= '9') {
            return (str - '0');
        } else {
            return (str - 'A' + 10);
        }
    } else {
        switch (str.len()) {
            case 2:
                return (hextoint(str[0]) << 4) + hextoint(str[1]);
            case 4:
                return (hextoint(str[0]) << 12) + (hextoint(str[1]) << 8) + (hextoint(str[2]) << 4) + hextoint(str[3]);
        }
    }
	}



	//function getSerialisedSize(eeprom,createhandler)
	//{
	//	local temp = createhandler();
	//	local size = eeprom.GetPageSize();
	//	local maxsize;
	//	if (imp.getmemoryfree() > 10000) maxsize = 8192;
	//	else if (imp.getmemoryfree() > 5000) maxsize = 4096;
	//	else if (imp.getmemoryfree() > 3000) maxsize = 2048;
	//	else maxsize = 1024;
	//	local tempblob = serializer.serialize(temp,maxsize);
	//	local nrPages = ((tempblob.len()/size)+1);
	//	return ({bytes = nrPages*size, pages = nrPages});
	//}

	function validateAndComplete(modeltovalidate, createhandler)
	{
		local desiredmodel = createhandler();
		local match = true;
		// basic checks
		if ((modeltovalidate == null) || (typeof modeltovalidate != "table"))
			return ({result = desiredmodel, match = false});
		else
		{
			foreach(prop,value in desiredmodel)
			{
				if (!(prop in modeltovalidate))
				{
					modeltovalidate[prop] <- value; // create entry with default value when it doesn't exist (eg stored with previous firmware model)
					match = false;
				}
			}
			return ({result = modeltovalidate, match = match});
		}
	}

	function tableDiff (origtable,newtable, devtable )
	{
		local changes = {}
		foreach(key,value in newtable)
		{
			if ((typeof value == "float") && (value.tostring() == "nan"))
			{
				// do nothing if nan (Not a Number)
			}
			else if (typeof value == "table")
			{
				if (key in origtable)
				{
					local diff = tableDiff(origtable[key], value,devtable[key]);
					if (diff.len() != 0)
						changes[key] <- diff;
				}
				else
					changes[key] <- clone value;
			}
			else
			{
				if (key in origtable)
				{
					if (devtable[key] == "N")
					{
						// do nothing
					}
					else if (devtable[key] == "A") // 0 in deviation table means : report every change
					{
						if (origtable[key] != newtable[key])
						{
							changes[key] <- value;
						}
					}
					else
					{
						local deviation = (newtable[key] - origtable[key]);
						deviation = (deviation < 0) ? -deviation : deviation;
						if (deviation > devtable[key])
						{
						  if ((typeof value == "float") || (typeof value == "integer"))
							  changes[key] <- roundTo(value, devtable[key]);
							else
							  changes[key] <- value;
						}
					}
				}
			}
		}
		return changes;
	}

		
	function tableTemplateCopy (tabletocopy)
	{
		local tabcopy = {}
		foreach(key,value in tabletocopy)
		{
		  switch (typeof value)
		  {
		    case "table":
				  tabcopy[key] = tableTemplateCopy(tabletocopy[key]);
				  break;
		    case "array":
		      foreach(member in tabletocopy[key])
				    tabcopy[key] = tableTemplateCopy(tabletocopy[key]);
				  break;				  
		    case "float":
				  tabcopy[key] <- 0.0;
				  break;
			  case "string":
			    tabcopy[key] <- "";
			    break;
			  case "integer":
			    tabcopy[key] <- 0;
			    break;	
			  case "bool":
			    tabcopy[key] <- false;
			    break;				    
			  default:
				  tabcopy[key] <- null;	
				  break;
		  }
		}
		return tabcopy;
	}
	
	function roundTo(value, round)
	{
	  local multround = round;
	  local mult = 1;

	  // determine multiplicator
	  while (math.floor(multround) != multround)
	  {
	    multround = multround*10;
	    mult = mult*10;
	  }
	  mult = mult/multround;
	  
	  return ((math.floor(value*mult+0.5)/mult));
	}
	
	function tableRoundedCopy (tabletocopy,roundingtable)
	{
		local tabcopy = {}
		foreach(key,value in tabletocopy)
		{
		if (roundingtable[key] != "N")
		  switch (typeof value)
		  {
		    case "table":
				  tabcopy[key] = tableRoundedCopy(value,roundingtable[key]);
				  break;
		    case "array":
		      foreach(member in value)
				    tabcopy[key] = tableRoundedCopy(tabletocopy[key],roundingtable[key]);
				  break;				  
		    case "float":
//		      if ((value.tostring() != "nan") && (typeof roundingtable[key] != "string"))
		      if (typeof roundingtable[key] != "string")
				    tabcopy[key] <- roundTo(value, roundingtable[key]);
					else
						tabcopy[key] <- value;
				  break;
			  case "string":
			    tabcopy[key] <- "";
			    break;
			  case "integer":
		      if (typeof roundingtable[key] != "string")
				    tabcopy[key] <- roundTo(value.tofloat(), roundingtable[key]);
					else
						tabcopy[key] <- value;
			    break;	
			  case "bool":
			    tabcopy[key] <- false;
			    break;				    
			  default:
				  tabcopy[key] <- null;	
				  break;
		  }
		}
		return tabcopy;
	}


	function selectiveUpdateTable(target,changes)
	{
		foreach (key,value in target)
		{
			if (typeof value == "table")
			{
				if (key in changes)
				{
					local diff = selectiveUpdateTable(target[key],changes[key]);
				}
			}
			else // it's concerning a lowest level key
			{
				if (key in changes)
					target[key] = changes[key];
			}
		}
	}


	function FindChangedKeys(origtable,newtable)
	{
		local changedprops = [];
		local keysok = true;
		foreach(key,value in origtable)
		{
			if (!(key in newtable))
			{
			  server.log("Key not found : " + key);
				keysok = false;
				return "invalid";
			}
			else
			{
        if (newtable[key] != value)
				  changedprops.push(key);
			}
		}
		return changedprops;
	}



	function TableStructureCompare(model,data)
	{
		if (data == null)
			return TableCompare.DataEmpty;

		if (model == null)
			return TableCompare.ModelEmpty;

		local resultMinD = true;
		foreach (prop,value in model)
			if (!(prop in data))
			{				
				resultMinD = false;
			}

		local resultDinM = true;
		foreach (prop,value in data)
			if (!(prop in model))
			{				
				resultDinM = false;
			}

	 if (resultMinD && resultDinM)
		 return TableCompare.Identical
	 if (resultMinD)
			return TableCompare.ModelInData;
	 if (resultDinM)
			return TableCompare.DataInModel;
	 
	}

	/***************************************************************
	* copies 2 tables and returns an array with changed property names
	* returns "invalid" when 2 tables don't match
	***************************************************************/
	function tablecopy(origtable,newtable)
	{
		local changedprops = [];
		local keysok = true;
		foreach(key,value in origtable)
		{
			if (!(key in newtable))
			{
			  server.log("Key not found : " + key);
				keysok = false;
				return "invalid";
			}
			else
			{
        if (newtable[key] != value)
				  changedprops.push(key);
			}
		}
		origtable = clone newtable;
		return changedprops;
	}
	
	function CheckBit(prop, mask)
	{
		return ((prop & mask) == mask);
	}

	function CheckBitToFloat(prop, mask)
	{
		return ((prop & mask) == mask).tofloat();
	}


	function BitConditionalAssign(prop,mask,assignvalue)
	{
		return (((prop & mask) == mask) ? assignvalue : 0);
	}

	function SetBoolBit(boolvalue, bitnr)
	{
		local returnvalue;
		if (returnvalue)
			boolvalue =  (0x01 << bitnr);
		else
			returnvalue = 0;
		return returnvalue;
	}

	function compareBlob(blob1,blob2)
	{
		local result = {equal = true, cantcompare = false};
		if (blob1.len() != blob2.len())
		{
			result.cantcompare = true;
			result.equal = false;
		}
		else
		{
			for (local i = 0; i < blob1.len(); i++)
			{
				if (blob1[i] != blob2[i])
				{
					result.equal = false;
					break;
				}
			}
		}
		return result;
	}

	function getUUID() {
    // Generate an unique id
    local id = math.rand();
    return id;
	}

}

lib.init();
/*************************************************************************
#include "..\..\..\Classes2_0\Tools\Debug.ston.nut"
*************************************************************************/
debug <- 
{
	Logs = []

	function init()
	{
	}

	function strsimpletable(t)
	{
		local str = "{"
		foreach(k,v in t)
		{
			str+= k + ":" + v + ",";
		}
		str = str.slice(0,str.len()-1) + "}";
		return str;
	}

	function strsimplearray(b)
	{
		local str = "["
		foreach(k,v in t)
		{
			str+= k + ":" + v + ",";
		}
		str = str.slice(0,str.len()-1) + "}]";
		return str;
	}

	function _isTable(x) 
	{
		return typeof x == typeof {}
	}


	function _isArray(x) 
	{
		return typeof x == typeof []
	}

	function _isBlob(x) 
	{
		return typeof x == "blob"
	}

	function _prettyFormat(x) 
	{
		if (_isTable(x)) {
			local table = "(table : {"
			local separator = ""
			foreach (k, v in x) {
				table += separator + k + "=" + _prettyFormat(v)
				separator = ", "
			}
			return table + "})"
		} 
		else if (_isArray(x)) 
		{
			local array = "(array : ["
			local separator = ""
			foreach (e in x) {
				array += separator + _prettyFormat(e)
				separator = ", "
			}
			return array + "])"	
		} 
		else if (_isBlob(x)) 
		{
			BlobLogMulti(t, t.len());
		} 
		else if (x == null) {
			return "(null)"
		} else {
			if (typeof x == typeof 1.2)
				return "(" + typeof x + " : " + format("%f", x) + ")"
			else
				return "(" + typeof x + " : " + x + ")"

		}
	}


	function stringify(t, i = 0) {

    local indentString = "DEBUGLOG: ";
    for(local x = 0; x < i; x++) indentString += ".";
 
		if (typeof(t) == "blob")
		{
			BlobLogMulti(t, t.len());
		}
    else if (typeof(t) != "table" && typeof(t) != "array") 
		{
        server.log(indentString + t)
    } 
		else 
		{
        foreach(k, v in t) 
				{
            if (typeof(v) == "table" || typeof(v) == "array") 
						{
                local par = "[]";
                if (typeof(v) == "table") par = "{}";
                
                server.log(indentString + k + ": " + par[0].tochar());
                stringify(v, i+4);
                server.log(indentString + par[1].tochar());
            } 
            else 
						{ 
                server.log(indentString + k + ": " + v);
            }
        }
    }

	}

	function readlog()
	{
		local len = Logs.len();
		local toReturn = array(len);
		for (local i = 0; i < len; i++)
			toReturn[i] = Logs[i];
		Logs.clear();	

		return toReturn;
	}

	function log(logstr)
	{
		if (lib.is_agent())
		{
			local t = lib.timestamp;
			Logs.push(lib.timestamp + " " + lib.selfstr.toupper() + " : " + logstr);
		}
		server.log(logstr);
	}

	function error(logstr)
	{
		if (lib.is_agent())
		{
			local t = lib.timestamp;
			Logs.push(lib.timestamp + " " + lib.selfstr.toupper() + " ERROR :" + logstr);
			if (Logs.len() > 1000)
			{
				for (local i = 0; i < 100; i++)
					Logs.remove(0);
			}
		}
		server.error(logstr);
	}

	function BlobLogMulti(SrcBlob, NrBytes)
	{
		local LogStrLine = "";

		for (local i = 0; i < (NrBytes / 32); i++)
		{
			LogStrLine = format("[%04x]:", i * 32);
			for (local j = 0; j < 32; j++)
			{
				if (i * 32 + j < NrBytes)
					LogStrLine = format("%s%02x ", LogStrLine, SrcBlob[i * 32 + j]);
				else
					LogStrLine = format("%s-- ", LogStrLine);
			}
			server.log(LogStrLine);
		}
	}

	function LogSingle(SrcBlob)
	{
		local LogStrLine = "";

		for (local j = 0; j < SrcBlob.len(); j++)
		{
			LogStrLine = format("%s%02x ", LogStrLine, SrcBlob[j]);
		}
		server.log(LogStrLine);
	}

}

debug.init();
/*************************************************************************
#include "..\..\..\Frameworks\VdcEventFrame\V1.0.0\VdcEventFrame.ston.nut"
*************************************************************************/
const EVENTPERIOD = 0.05;

gEvents <-
{
	_eventcnt = 0
		_events = {}
	_remotesublist = []
	_running = false

	function _regularCheck()
	{
		foreach(entrykey,entry in _events)
		{
			if (entry.state == true)
			{
				// only reset the event flag if there are subscribers
				// this allows the use of events on a discrete checking basis.
				if (entry.subscribers.len() != 0)
				{
					entry.state = false;
					// execute the handler for each subscribed process/context if event is set
					foreach(subkey,sub in entry.subscribers)
					{
						if ((entrykey != "LastConnecttick") && 
							(entrykey != "sectimertick") && 
							(entrykey != "evaluatetimeandswitchtick") && 
							(entrykey != "TaskSMMaintick"))
							Log("Events",format("[Event:%s] Handler executed for subscriber %s",entrykey,subkey));
						sub(entry.param);
					}
				}
			}
		}
		imp.wakeup(EVENTPERIOD,_regularCheck.bindenv(this));
	}


	function RegisterEvent(name)
	{
		if (!HasEvent(name))
		{
			Log("Events","[gEvents(" + lib.selfstr + "):RegisterEvent] Registering event " + name);
			_events[name] <- {state = false,subscribers = {},param = null};
			_eventcnt++;
		}
	}

	function UnRegisterEvent(name)
	{
		Log("Events","[gEvents(" + lib.selfstr + "):UnRegisterEvent] UnRegistering event " + name);
		// then delete the event entry
		delete _events[name];
	}

	function HasEvent(name)
	{
		return (name in _events);
	}

	// TODO: make unsubscribe method

	/*************************************************************************/
	/*! 
	    \brief 	function SetEvent(Eventname,param=null)
	
	    Sets event 'name' with associated parameters
	
	    @param[in]  	eventname[string] ; param [table]   
	          [desc]	eventname : name if the event to set ; 
										param : simple type or table that will be passed to the handler if execution occurs
	
	    \return     	bool : success : true is event was set, "false' if event doesn't exist
	    \note       	
	    \warning    	
	*/
	/*************************************************************************/
	function SetEvent(eventname,param=null)
	{
		if ((eventname != "LastConnecttick") && 
			  (eventname != "sectimertick") && 
				(eventname != "evaluatetimeandswitchtick") && 
				(eventname != "TaskSMMaintick"))
			Log("Events","[gEvents(" + lib.selfstr + "):SetEvent] Setting event " + eventname);
		RegisterEvent(eventname);
		_events[eventname].state = true;
		_events[eventname].param = param;
	}

/* /*************************************************************************/
/*! 
    \brief 	function CheckEventAndClear(Event)

    Checks the state of the event with 'name' and return the state + potential 
		parameters that were set during the SetEvent call. Event state is cleared after this call

    @param[in]  'name' = name of the concerned event   
                [desc]

    \return     table with keys 'state' and 'param'. Returns null if event does not exist
    \note       
    \warning    
*/
/*************************************************************************/   
	function CheckEventAndClear(eventname)
	{
		RegisterEvent(eventname);
		local state = _events[eventname].state;
		_events[eventname].state = false;

		return {state = state,param = _events[eventname].param}
	}

/* /*************************************************************************/
/*! 
    \brief function CheckEvent(Event)

    Checks the state of the event with 'name' and return the state + potential parameters that were set during the SetEvent call

    @param[in]  'name' = name of the concerned event   
                [desc]

    \return     table with keys 'state' and 'param'. Returns null if event does not exist
    \note       
    \warning    
*/
/*************************************************************************/   
	function CheckEvent(eventname)
	{
		RegisterEvent(eventname);
		return {state = _events[eventname].state,param = _events[eventname].param}
	}

	function ClearEvent(eventname)
	{
		_events[eventname].state = false;
		_events[eventname].param = null;
	}

	function ClearAllEvents()
	{
		foreach(event in _events)
		{
			event.state = false;
			event.param = null
		}
	}

	function Subscribe(eventname, subscriptionname, handler,remote = false)
	{

		local remotestr = (remote) ? "remote" : " ";
		// eliminates the need to explicitely register an event up front
		RegisterEvent(eventname);

		// avoid error when assigning subscriber that is already subscribed
		if (!(subscriptionname in _events[eventname].subscribers))
		{
			// associate the handler for the subscription including the caller's desired context
			_events[eventname].subscribers[subscriptionname] <- handler;
			Log("Events","[gEvents(" + lib.selfstr + ").Subscribe] Subscribed " + remotestr + " handler for Event(" + eventname + ")/subscriber(" + subscriptionname +") handler:" + handler);
		}

		// notify the other side that a remote subscription is requested
		if (remote)
		{
			lib.partner.send("eventsubscribe",{eventname = eventname,subscriptionname = subscriptionname});
			// store the requested remote subscription requests so we can recreate them later on upon request.
			_remotesublist.push({eventname = eventname,subscriptionname = subscriptionname});
		}
	}

	function UnSubscribe(eventname, subscriptionname)
	{
			Log("Events","[gEvents(" + lib.selfstr + ").UnSubscribe] UnSubscribed handler for Event(" + eventname + ")/subscriber(" + subscriptionname +") handler");
			_events[eventname].subscribers.rawdelete(subscriptionname);
	}

	function IsRunning()
	{
		return _running;
	}

	function StartEventChecking()
	{
		// ask to resubmit the remote subscription requests.
		// If both are booting, these lists are empty anyway...
		lib.partner.send("resubmitremotesubs",null);
		_running = true;
		_regularCheck();
		// setting up the remote event triggering mechanism - there's no ack functionality.
		// handle the remote subscription event
		lib.partner.on("eventsubscribe",function(param)  {
			// create a subscription handler which basically sends an event to agent/device instead of executing a local handler
			Subscribe(param.eventname, param.subscriptionname, function(eventparam){lib.partner.send("executeeventhandler",{name = param.eventname,subname = param.subscriptionname,param = eventparam});
			});
		}.bindenv(this));
				// execute the handler associated to the remote event
		lib.partner.on("executeeventhandler",function(data) {SetEvent(data.name,data.param);}.bindenv(this));
		// respond to a request to resubmit the remote subscription list. 
		lib.partner.on("resubmitremotesubs",function(data){
			Log("Startup","[gEvents:StartEventChecking] resubmitremotesubs requested");
			// if we get a request to resubmit remote subs (after the partner has booted),
			// take the previously stored list of requests for remote subscription and resubmit them
			// in case of joint booting, both parties will issue this request, but the lists will be empty anyway...
			foreach(sub in _remotesublist)
					lib.partner.send("eventsubscribe",{eventname = sub.eventname,subscriptionname = sub.subscriptionname});
			}.bindenv(this));
		// request it after 10 secs. We can assume that when both are booting, all remote subscriptions have been statically set up
	}
}

gEvents.StartEventChecking();

/*************************************************************************
#include "..\..\..\Frameworks\VdcLoggingFrame\V1.0.0\VdcLoggingFrame.device.ston.nut"
*************************************************************************/

dataDebugAndTrace <- 
{
	Errors = true
	Startup = true
	Connection = true
	Rest = false
	Bull = false
	Events = false
	AppL1 = true
	AppL2 = false
	AppL3 = false
	HostL1 = false
	HostL2 = false
}

function LogInit(startupSelection)
{
	if ("Errors" in startupSelection)
		dataDebugAndTrace.Errors = startupSelection.Errors;

	if ("Startup" in startupSelection)
		dataDebugAndTrace.Startup = startupSelection.Startup;
	if ("Connection" in startupSelection)
		dataDebugAndTrace.Connection = startupSelection.Connection;

	if ("Rest" in startupSelection)
		dataDebugAndTrace.Rest = startupSelection.Rest;

	if ("Bull" in startupSelection)
		dataDebugAndTrace.Bull = startupSelection.Bull;

	if ("Events" in startupSelection)
		dataDebugAndTrace.Events = startupSelection.Events;

	if ("AppL1" in startupSelection)
		dataDebugAndTrace.AppL1 = startupSelection.AppL1;

	if ("AppL2" in startupSelection)
		dataDebugAndTrace.AppL2 = startupSelection.AppL2;

	if ("AppL3" in startupSelection)
		dataDebugAndTrace.AppL3 = startupSelection.AppL3;

	if ("HostL1" in startupSelection)
		dataDebugAndTrace.HostL1 = startupSelection.HostL1;

	if ("HostL2" in startupSelection)
		dataDebugAndTrace.HostL2 = startupSelection.HostL2;

	if (!"gDeviceBull" in getroottable())
	{
		server.error("gDeviceBull required for framework operation ! Creating default...");
		gDeviceBull <- Bullwinkle(
								{ "messageTimeout": 10,    // If there is no response from a message in 10 seconds,
																					// consider it failed
									"retryTimeout": 10,     // Calling package.retry() with no parameter will retry
														              // in 10 seconds
									"maxRetries": 3         // Limit to the number of retries to 3
								});
	}

	gDeviceBull.on("SyncDebugAndTrace",function(message, reply) {
		dataDebugAndTrace = message.data;
		reply({status = "ok"});
	});
}



function Log(level,strtolog)
{
	if (level in dataDebugAndTrace)
	{
		if (dataDebugAndTrace[level])
			server.log(strtolog);
	}
	else
	{
		server.error(format("[VdcLoggingFrame] Non existing log qualifier '%s', log suppressed", level));
	}
}

function ErrorLog(strtolog)
{
		if (dataDebugAndTrace["Errors"])
			server.error(strtolog);
}
/*************************************************************************
#include "..\..\..\Classes2_0\Queue\V1.0.0\Queue.class.nut"
*************************************************************************/

enum eQueueType
{
	fifo,
	lifo
}

class Queue
{
	_buffer = null;
	_type = null;

	constructor(type)
	{
		_buffer = [];
		_type = type;
	}

	function SendToBack(element)
	{
		_buffer.push(element);
	}

	// sends new element to be processed to the front of the queue. Can be used to implement priority schemes.
	function SendToFront(element)
	{
		_buffer.insert(0,element);
	}

	function Receive()
	{
		local toreturn;
		switch(_type)
		{
		case eQueueType.lifo:
			toreturn = _buffer.pop();
			break;
		case eQueueType.fifo:
			toreturn = _buffer[0];
			_buffer.remove(0);
			break;
		}
		return toreturn;
	}

	function Peek()
	{
		local toreturn;
		switch(_type)
		{
		case eQueueType.lifo:
			toreturn = _buffer.top();
			break;
		case eQueueType.fifo:
			toreturn = _buffer[0];
			break;
		}
		return toreturn;
	}

	function Inspect(elementnr)
	{
		return _buffer(elementnr);
	}

	function ElementsWaiting()
	{
		return _buffer.len();
	}

	function Clear()
	{
		_buffer.clear();
	}
}
/*************************************************************************
#include "..\..\..\Classes2_0\GuardedProcessQueue\V2.0.0\GuardedProcessQueue.class.nut"
*************************************************************************/
	enum eGPQStates {
		Init,
		WaitToProcess,
		LaunchProcessing,
		Processing,
		ProcessingComplete,
		ProcessingTimeout,
		ProcessMaxRetries,
		Exception
	}

class GuardedProcessQueue extends Queue
{
	static VERSION = "2.0.0";

	_name = null;
	_processendEvent = null;
	_sequenceNr = null;
	_processHandler = null;
	_timeoutHandler = null;
	_exceptionHandler = null;
	_readyHandler = null;
	_maxretryHandler = null;
	_maxelementHandler = null;

	_processingPeriod = null;
	_processingResult = null;

	_maxElements = null;
	_maxRetries = null;
	_retryCnt = null;
	_timeoutCnt = null;
	_processingSmState = null;
	_execInterval = null;
	_timeoutPeriod = null;
	_currentItemToProcess = null;

	/********************************************************
	name : name of the queue
	type : eQueueType.fifo or eQueueType.lifo
	timeout : (float) timeout perios in seconds after which the queue gets unblocked. 
						if timeout = 0, queue is unblocked immediately, no waiting for end of process is assumed
	minperiod : (float) minimal period between executions (in secs) to deal with access frequency limited resources
								eg. EEPROM with limited write cycles, web service with max # connections/period, ...
	overwrite : true ==> if elements (with a particular name) are added to the queue while there 
								are other elements with the same name already in the queue, the newer value 
								will overwrite the old ones
								=> eg when access to an eeprom is limited to one write per 10 seconds, 
								then of all write requests that arrive within those 10 seconds (with the same name) 
								only the most recent will be written. This to avoid unnecessary writes.
							false ==> all processing requests will be executed
	*********************************************************/
	// Define the Task and its underlying SM behaviour) 




	constructor(name, type, timeout , maxRetries,execInterval,maxelements = 30 )
	{
		base.constructor(type);
		_name = name;
		_processendEvent = "GPQ_" + _name + "processend";
		_maxElements = maxelements;
		_processingSmState = eGPQStates.Init;
		_retryCnt = 0;
		_timeoutCnt = 0;
		_timeoutPeriod = timeout;
		_execInterval = execInterval;
		_maxRetries = maxRetries;
		_sequenceNr = 0;

		// check the dependencies
	 	if (!("gEvents" in getroottable()))
				throw ("[GuardedProcessQueue-ctor " + _name + "] Cannot instantiate GuardedProcessQueue without Event framework included");

		if (!("lib" in getroottable()))
				throw ("[GuardedProcessQueue-ctor " + _name + "] Cannot instantiate GuardedProcessQueue without Lib functions included");
		
		// check for inclusion of logging framework
		if (!("dataDebugAndTrace" in getroottable()))
				throw ("[GuardedProcessQueue-ctor " + _name + "] Cannot instantiate GuardedProcessQueue without Logging framework included");

		// event used to indicate end of processing
		gEvents.Subscribe(_processendEvent,"guard",function(param)
		{
			// check if response is from last issued process, if not, ignore
			if (param.s == _sequenceNr)
			{
				_processingResult = param.result;
				_processingSmState = eGPQStates.ProcessingComplete;
			}
		}.bindenv(this));
	}



	function _processSm()
	{
		try 
		{

			switch(_processingSmState)
			{
			/**************************************************************************/
			/* State : init																														*/
			/**************************************************************************/
			case eGPQStates.Init:
				Log("AppL1","[GuardedProcessQueue(" + _name + "):_processSm] : Starting up...");
				_processingSmState = eGPQStates.WaitToProcess;
				break;
			/**************************************************************************/
			/* State : WaitToProcess																									*/
			/* Waits until a new item to process arrives in the queue									*/
			/**************************************************************************/
			case eGPQStates.WaitToProcess:
				// new entry in queue
				if (_buffer.len() != 0) 
				{
					_currentItemToProcess = base.Receive();
					Log("AppL3","[GuardedProcessQueue(" + _name + "):_processSm]  Processing Item /" + _currentItemToProcess.n + "/, " +  _buffer.len() + " elements remaining in queue");	
					_retryCnt = 0;

					_processingSmState = eGPQStates.LaunchProcessing;		
				}
				// else just carry on in the waiting state
				break;
			/**************************************************************************/
			/* State : LaunchProcessing																								*/
			/* Waits until a new item to process arrives in the queue									*/
			/**************************************************************************/
			case eGPQStates.LaunchProcessing:
				// new entry in queue
					_timeoutCnt = 0;
					_processingPeriod = 0;
					_sequenceNr++;
					// if no specific handler is defined for this entry, then use the generic one
					if (_currentItemToProcess.h == null) 
					{
						if (_processHandler != null) 
						{
							_processHandler(_currentItemToProcess.e,_sequenceNr);
						}
					}
					else
						_currentItemToProcess.h(_currentItemToProcess.e,_sequenceNr);
					_processingSmState = eGPQStates.Processing;		

				break;
			/**************************************************************************/
			/* State : Processing																											*/
			/* Wait while executing the associated process														*/
			/**************************************************************************/
			case eGPQStates.Processing:
				_processingPeriod += _execInterval;
				// check timeout
				if (_execInterval*_timeoutCnt++ > _timeoutPeriod) 
					_processingSmState = eGPQStates.ProcessingTimeout;		
				// shift to the next state is done asynchronously in the Event handler picking up the completed event
				break;
			/**************************************************************************/
			/* State : ProcessingComplete																							*/
			/* execute Ready handler & go back to processing next item								*/
			/**************************************************************************/
			case eGPQStates.ProcessingComplete:
				if (_readyHandler != null) 
					_readyHandler(_processingResult,_processingPeriod, _retryCnt);
				_processingSmState = eGPQStates.WaitToProcess
				break;
			/**************************************************************************/
			/* State : ProcessingTimeout																							*/
			/* Check for # max retries & restart process															*/
			/**************************************************************************/
			case eGPQStates.ProcessingTimeout:
				// check max retries
					if (_retryCnt >= _maxRetries)
						_processingSmState = eGPQStates.ProcessMaxRetries
					else
					{
						if (_timeoutHandler != null) _timeoutHandler(_timeoutPeriod,_retryCnt);
						Log("AppL3","[GuardedProcessQueue(" + _name + "):_processSm] Timeout occured waiting for processing, retries = " + _retryCnt);	
						_retryCnt++;
						_processingSmState = eGPQStates.LaunchProcessing
					}
				break;
			/**************************************************************************/
			/* State : ProcessMaxRetries																							*/
			/* If max retries is reached, execute max retry handler										*/
			/**************************************************************************/
			case eGPQStates.ProcessMaxRetries:
				Log("AppL3","[GuardedProcessQueue(" + _name + "):_processSm]  Timeout occured after max retries (" + _retryCnt + ")");	
				if (_maxretryHandler != null) _maxretryHandler(_retryCnt);
				_processingSmState = eGPQStates.WaitToProcess
				break;
			/**************************************************************************/
			/* State : Exception																							*/
			/* If max retries is reached, execute max retry handler										*/
			/**************************************************************************/
			case eGPQStates.Exception:
				// for now, simply restart after the assigned exceptionhandler
				_processingSmState = eGPQStates.Init;
				break;
			}
		}
		catch(e)
		{
			ErrorLog("[GuardedProcessQueue(" + _name + "):_processSm] Exception encountered in state " + _processingSmState + " : " + e);
			if (_exceptionHandler != null) _exceptionHandler(_processingSmState,e);
			_processingSmState = eGPQStates.Exception;
		}
		imp.wakeup(_execInterval,_processSm.bindenv(this));
	}

	function StartProcessing()
	{
		// start processing
		_processSm();
	}

	// sets a generic handler if none is supplied with the queued elements
	function onProcess(processhandler)
	{
		_processHandler = processhandler;
	}

	function onReady(handler)
	{
		_readyHandler = handler;
	}

	function onTimeout(handler)
	{
		_timeoutHandler = handler;
	}

		function onMaxretries(handler)
	{
		_maxretryHandler = handler;
	}

	function onException(handler)
	{
		_exceptionHandler = handler;
	}

	function onMaxElements(handler)
	{
		_maxelementHandler = handler;
	}

	function GetUnlockEvent()
	{
		return _processendEvent;
	}

	// overridden base functions
	function SendToBack(name, element, handler = null)
	{
		if (base.ElementsWaiting() > _maxElements)
		{
			ErrorLog("[GuardedProcessQueue(" + _name + "):SendToBack] Max number of elements reached (" + _maxElements + "), ignoring");
			if (_maxelementHandler != null)
				_maxelementHandler({n = name,e = element,h = handler});
		}
		else
			base.SendToBack({n = name,e = element,h = handler});
	}

	// sends new element to be processed to the front of the queue. Can be used to implement priority schemes.
	function SendToFront(name, element, handler = null)
	{
		if (base.ElementsWaiting() > _maxElements)
		{
			ErrorLog("[GuardedProcessQueue(" + _name + "):SendToBack] Max number of elements reached (" + _maxElements + "), ignoring");
			if (_maxelementHandler != null)
				_maxelementHandler();
		}
		else
			base.SendToFront({n = name,e = element,h = handler});
	}
}


server.log("**********************************************************");
server.log("Starting " + imp.environment());
server.log("**********************************************************");

testProcess <- GuardedProcessQueue("Test",eQueueType.fifo,10,3,0.05,30);

testProcess.onProcess(function(element,seq){
    server.log("Executing generic handler on " + element);
    gEvents.SetEvent(testProcess.GetUnlockEvent(),{result="OK Generic",s=seq});
    
});
testProcess.onReady(function(result,period,retrycnt){server.log("Executing ready handler with result " + result + ": in " + period + "msecs after " + retrycnt + " retries with " + testProcess.ElementsWaiting() + " waiting in queue");  });
testProcess.onTimeout(function(timeoutperiod,retrycnt){server.log("Executing timeout handler after " + timeoutperiod + " msecs and " + retrycnt + " retries");  });
testProcess.onMaxretries(function(retrycnt){server.log("Executing maxretries handler after " + retrycnt + " retries");  });
testProcess.onException(function(state,e){server.log("Executing exception handler at state  " + state +  " with exception : " + e);  });
testProcess.onMaxElements(function(item){server.log("Executing max element handler on " + item.n  );  });


testProcess.StartProcessing();

globalcnt <- 0;

// repetitive injection of an element to process
function injectElement()
{

	for (local i = 0; i < 4; i++)
	{
	  server.log(format("Inserting Element %d in processing queue",globalcnt ));
		if (i%2 == 0)
			testProcess.SendToBack("even",format("Even Element %d",globalcnt++),function(element,seq){
			    server.log("Executing specific handler [" + element + "] on " + element); 
			    injectEvent(seq);
			    
			});
		else
			testProcess.SendToBack("odd",format("Odd Element %d",globalcnt++));
	}
	imp.wakeup(10,injectElement);		
}

// repetitive sending of unlocking events.
function injectEvent(seq)
{
	
	imp.wakeup(12,function(){gEvents.SetEvent(testProcess.GetUnlockEvent(),{result="OK Specific",s=seq});});
}
injectElement();

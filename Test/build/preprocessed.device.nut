//line 1 "src\device.nut"
#require "utilities.lib.nut:3.0.1"


//line 1 "github:vedecoid/SquirrelLib_Tools/./VdcLogging.nut"

//line 1 "github:vedecoid/SquirrelLib_VdcLoggingFrame/src/VdcLoggingFrameLocal.lib.nut"

function Log(type,msg) {
	if ("gShowall" in ::getroottable())
		server.log(msg);
	else if ((type == "AppL1") || (type == "AppL2")) 
		server.log(msg);
}

function ErrorLog(strtolog)
{
	server.error(strtolog);
}
//line 7 "github:vedecoid/SquirrelLib_Tools/./VdcDefaultFileHeader.nut"


/*************************************************************************
Project   : GuardedProcessQueue Library Device Test
Source    : VdcDefaultFileHeader.nut

Version   : 2.2.0
Build     : 
Copyright : (c)2019 Verhaegen Development Company
*************************************************************************/

function bootMessage() {
    // Present OS version and network connection information
    // Take the software version string and extract the version number
    local a = split(imp.getsoftwareversion(), " - ");
	Log("AppL1","impOS version " + a[2]);

	// Get current networking information
local netData = imp.net.info();
if ("active" in netData) {
    local type = netData.interface[netData.active].type;
    
    // We have an active network connection - what type is it?
    if (type == "cell") {
        // The imp is on a cellular connection
        local imei = netData.interface[netData.active].imei;
        Log("AppL1","Connection: The imp has IMEI " + imei + " and is connected via cellular");
    } else {
        // The imp is connected by WiFi or Ethernet
        local ip = netData.ipv4.address;
        Log("AppL1","Connection: The imp has IP address " + ip + " and is connected via " + type);
    }
    
    if (netData.interface.len() > 1) {
        // The imp has more than one possible network interface
        // so note the second (disconnected) one
        local altType = netData.active == 0 ? netData.interface[1].type : netData.interface[0].type;
        Log("AppL1","Connection: (It can also connect via " + altType + ")");
    }
} else {
    Log("AppL1","Connection: The imp is not connected");
}
	// Present the reason for the start-up
	local s = logWokenReason();
	if (s.len() > 0) Log("AppL1",s);
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

const BUILDNRSTR = "null";
const VERSIONSTR = "2.2.0";

Log("AppL1","");
Log("AppL1","***********************************************************");
Log("AppL1",format("Application :%s ","GuardedProcessQueue Library Device Test"));
Log("AppL1",format("Product : %s / %s"__EI.PRODUCT_NAME ,__EI.DEVICEGROUP_NAME));
Log("AppL1",format("Version : %s-%s",VERSIONSTR,__EI.DEVICEGROUP_TYPE));
Log("AppL1",format("Build SHA : %s (%s)",__EI.DEPLOYMENT_SHA,__EI.DEPLOYMENT_CREATED_AT));
Log("AppL1",format("Module Type : % s",(imp.environment() == ENVIRONMENT_AGENT) ? "Agent" : imp.info().type));
Log("AppL1",format("Id/Url : %s",(imp.environment() == ENVIRONMENT_AGENT) ? http.agenturl() : hardware.getdeviceid()));
if (imp.environment() != ENVIRONMENT_AGENT) {
  bootMessage();
  }
Log("AppL1","***********************************************************");
Log("AppL1","");

//line 4 "github:vedecoid/SquirrelLib_Tools/./VdcMacros.nut"

//line 1 "github:vedecoid/SquirrelLib_Tools/./VdcFrameworksCheck.nut"
function IsTimerFrameLoaded()
{
	return (("TimerFrame" in getroottable()) || ("gScheduler" in getroottable()));
}

function IsEventFrameLoaded()
{
	return ("gEvents" in getroottable());
}

function IsLoggingFrameLoaded()
{
	return ("Log" in getroottable()); 
}


function IsLocalTimeProviderLoaded()
{
	return ("gTime" in getroottable()); 
}
//line 1 "github:vedecoid/SquirrelLib_Tools/./VdcUtilities.lib.nut"
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
			  Log("AppL1","[Utilities:FindChangedKeys] Key not found : " + key);
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
			  Log("AppL1","[Utilities:tablecopy] Key not found : " + key);
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
//line 1 "github:vedecoid/SquirrelLib_Tools/./VdcDebug.lib.nut"
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
        Log("AppL1",indentString + t)
    } 
		else 
		{
        foreach(k, v in t) 
				{
            if (typeof(v) == "table" || typeof(v) == "array") 
						{
                local par = "[]";
                if (typeof(v) == "table") par = "{}";
                
                Log("AppL1",indentString + k + ": " + par[0].tochar());
                stringify(v, i+4);
                Log("AppL1",indentString + par[1].tochar());
            } 
            else 
						{ 
                Log("AppL1",indentString + k + ": " + v);
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
		Log("AppL1",logstr);

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
		//#ifdef DEBUG
		server.error(logstr);
		//#endif	
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
			Log("AppL1",LogStrLine);
		}
	}

	function LogSingle(prefixStr,SrcBlob)
	{
		local LogStrLine = prefixStr;

		for (local j = 0; j < SrcBlob.len(); j++)
		{
			LogStrLine = format("%s%02x ", LogStrLine, SrcBlob[j]);
		}
		Log("AppL1",LogStrLine);
	}

}

function getSize(limit,object=""){
    local tree={}
    local obj = getroottable()
  
    if (object!="") {
        foreach (element in split(object,"./")) 
            if (element in obj)
                obj = obj[element]
            else
                return "cannot resolve object: "+object
    }
    return { [object+"@"+sizeOf(obj,[],limit,tree)]=tree }
}

// Values for Agent//Device
const SIZE_STRING = 24
const SIZE_BLOB = 64
const SIZE_FUNCTION = 44

const SIZE_TABLE_EMPTY = 124
const SIZE_TABLE_BASE = 124
const SIZE_TABLE_ELEMENT = 24

const SIZE_ARRAY_EMPTY = 68
const SIZE_ARRAY_BASE = 36
const SIZE_ARRAY_ELEMENT = 8

const SIZE_INSTANCE_EMPTY = 72
const SIZE_INSTANCE_BASE = 64
const SIZE_INSTANCE_ELEMENT = 8

const SIZE_CLASS_EMPTY = 348
const SIZE_CLASS_BASE = 384
const SIZE_CLASS_ELEMENT = 24


function sizeOf(object,objList,limit=0,sizeTree={}){
    
    // check for a scalar value
    switch(typeof(object)){
        case "integer":   
        case "float":
        case "bool":
        case "null":
            return 0
    }

    if (objList.find(object)!=null)  // check if already referenced
        return 0
    
    // object is previously unreferenced, put it on our list.
    objList.append(object)

    local size=0

    switch (typeof(object))
    {
        case "string":  // device increments in steps of 4 bytes
            return SIZE_STRING+object.len()+1

        case "blob":    // device increments in steps of 4 bytes
            return SIZE_BLOB+object.len()

        case "meta":
            return 0
            
        case "generator":
        case "function":
            return SIZE_FUNCTION

        case "table":   //empty table=240, base=80, each slot=40
            size = SIZE_TABLE_BASE + SIZE_TABLE_ELEMENT*object.len()
            
            // additional cost of 80>3, 160>8, 320>16, 640>32 ...
            local n=4
            while (n<object.len()) {
                size += n*20
                n*=2
            }
            break

        case "array": 
            if (object.len()==0)
                size = SIZE_ARRAY_EMPTY
            else
                size = SIZE_ARRAY_BASE + SIZE_ARRAY_ELEMENT*object.len()
            break
        
        case "instance":
            local count=0
            foreach(v in object.getclass()) count++ 
            if (count==0)
                size = SIZE_INSTANCE_EMPTY
            else
                size = SIZE_INSTANCE_BASE + SIZE_INSTANCE_ELEMENT*count
            break
            
        case "class":      
            local count=0
            foreach(v in object) count++ 
            if (count==0)
                size = SIZE_CLASS_EMPTY
            else
                size = SIZE_CLASS_BASE + SIZE_CLASS_ELEMENT*count
            
            // additional cost of 80>3, 160>8, 320>16, 640>32 ...
            local n=4
            while (n<count) {
                size += n*20
                n*=2
            }
            break
            
        default:
            server.log("Error: type="+typeof(object))
            return 0
    }
    
    foreach(k,v in (typeof(object)=="instance")?object.getclass():object) {
        local subTree = {}
        local subSize = sizeOf(k,objList) + sizeOf(object[k],objList,limit,subTree)
        if (subSize>limit) 
            sizeTree[k+"@"+subSize] <- (subTree.len()>0)?subTree:typeof(v)
        size += subSize
    }
    return size
}


debug.init();
//line 13 "src\device.nut"

//line 1 "github:vedecoid/SquirrelLib_Queue/src/Queue.lib.nut"

enum eQueueType
{
	fifo,
	lifo
}

class Queue
{
	static VERSION = "2.0.0";
	
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
//line 2 "..\src\GuardedProcessQueue.lib.nut"


const MAXPROCESSINGTIMEOUTPERIOD = 10;
/*	enum eGPQStates {
		Init,
		Idle,
		LaunchProcessingNew,		
		LaunchProcessing,
		Processing,
		ProcessingComplete,
		ProcessingError,
		ProcessingTimeout,
		ProcessMaxRetries,
		Exception
	}
*/
		enum eGPQStates {
		Init="Init",
		Idle="Idle",
		LaunchProcessingNew="LaunchProcessingNew",		
		LaunchProcessing="LaunchProcessing",
		Processing="Processing",
		ProcessingComplete="ProcessingComplete",
		ProcessingError="ProcessingError",
		ProcessingTimeout="ProcessingTimeout",
		ProcessMaxRetries="ProcessMaxRetries",
		Exception="Exception"
	}

class QueueEntry
{
	_data = null;
	_timeout = null;
	_processinghandler = null;
	_readyhandler = null;	
	_reference = null;

	constructor(reference, data,processinghandler, readyhandler,timeout)
	{
		_data = data;
		_timeout = timeout;
		_processinghandler = processinghandler;
		_readyhandler = readyhandler;
		_reference = reference;
	}

}

class GuardedProcessQueue extends Queue
{
	static VERSION = "2.0.0";

	_name = null;
	_genericProcessingHandler = null;
	_processingtimeoutHandler = null;
	_queueingtimeoutHandler = null;
	_exceptionHandler = null;
	_genericReadyHandler = null;
	_maxretryHandler = null;
	_maxelementHandler = null;
	_genericErrorHandler = null;

	_processingResult = null;
	_processingError = null;
	_processingTimeout = null;
	_queueingTimeout = null;

	_maxElements = null;
	_maxRetries = null;
	_retryCnt = null;
	_processingSmState = null;
	_timeoutMaxPeriod = null;

	_currentEntry = null;
	_timeoutwakeup = null;

	/********************************************************
	name : name of the queue
	type : eQueueType.fifo or eQueueType.lifo
	maxprocessingtimeout : (float) timeout perios in seconds after which the queue gets unblocked. 
						is is to protect against a scenario where processing is blocked and the processing handler doesn't properly handle timeout
	maxretries : nr of retries attempted before passing to the next item in queue
	maxelements : nr of entries that queue can hold. If exceeded a notification callback is triggered
	*********************************************************/
	// Define the Task and its underlying SM behaviour) 

	constructor(name, type, maxprocessingtimeout , maxretries,maxelements)
	{
		base.constructor(type);
		_name = name;	// name of the queue
		_maxElements = maxelements;
		_processingSmState = eGPQStates.Idle;
		_retryCnt = 0;
		_timeoutMaxPeriod = maxprocessingtimeout;
		_maxRetries = maxretries;
	}

 	function NotifyProcessingReady(result)
  {
		_processingResult = result;
		_cancelTimeoutProtection();
		ProcessChangeState(eGPQStates.ProcessingComplete);
	}

	function NotifyProcessingError(error)
  {
		_processingError = error;
		_cancelTimeoutProtection();
		ProcessChangeState(eGPQStates.ProcessingError);		
	}

	function NotifyProcessingTimeout(timeout)
  {
		_processingTimeout = timeout;
		_cancelTimeoutProtection();	
		ProcessChangeState(eGPQStates.ProcessingTimeout);		
	}

	function Unlock()
	{
		_processingSmState = eGPQStates.ProcessingComplete;
		_cancelTimeoutProtection();
		ProcessChangeState(eGPQStates.ProcessingComplete,0.1);	
	}

	function ProcessChangeState(state, delay = 0)
	{
		if (delay == 0)
		{
			Log("debug",format("Changing state to %s",state));
			_processingSmState = state;
			return imp.wakeup(0,function(){_processSm();}.bindenv(this));
		}
		else 
		{

			return imp.wakeup(delay,function(){
					Log("debug",format("Changing state to %s with delay %d",state,delay));
					_processingSmState = state;
					_processSm();
				}.bindenv(this));
		}
	}

	function _checkForEntry()
	{
		if (_buffer.len() != 0) 
		{
			ProcessChangeState(eGPQStates.LaunchProcessingNew);
		}
		else 
		{
			ProcessChangeState(eGPQStates.Idle);
		}
	}

	function _cancelTimeoutProtection()
	{
		if (_timeoutwakeup != null)
		{
					server.log("Cancelling lock-up protection")
			imp.cancelwakeup(_timeoutwakeup);		
			_timeoutwakeup = null;
		}
	}

	function _startTimeoutProtection()
	{
		server.log("Starting lock-up protection")
		_timeoutwakeup = ProcessChangeState(eGPQStates.ProcessingTimeout,_timeoutMaxPeriod);
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
				_checkForEntry();
				break;	

			case eGPQStates.Idle:
				break;
			/**************************************************************************/
			/* State : LaunchProcessing																								*/
			/* Waits until a new item to process arrives in the queue									*/
			/**************************************************************************/
			case eGPQStates.LaunchProcessingNew:
			// new entry, retrieve from queueu and reset retrycnt
				_currentEntry = base.Receive();
				_retryCnt = 0;			
				// change to the timeout state after the timeout period. This is needed in case the queue entry fails to notify timeout
				_startTimeoutProtection();

				// if no specific handler is defined for this entry, then use the generic one
				if (_currentEntry._processinghandler == null) 
				{
					if (typeof _genericProcessingHandler == "function") 
						_genericProcessingHandler(_currentEntry);
				}
				else
					_currentEntry._processinghandler(_currentEntry);
					// not really needed, but good to keep some separation of states
				ProcessChangeState(eGPQStates.Processing);
				break;				
			/**************************************************************************/
			/* State : LaunchProcessing																								*/
			/* Waits until a new item to process arrives in the queue									*/
			/**************************************************************************/
			case eGPQStates.LaunchProcessing:

				// change to the timeout state after the timeout period
				_startTimeoutProtection();

				// if no specific handler is defined for this entry, then use the generic one
				if (_currentEntry._processinghandler == null) 
				{
					if (typeof _genericProcessingHandler == "function") 
						_genericProcessingHandler(_currentEntry);
				}
				else
					_currentEntry._processinghandler(_currentEntry);
					// not really needed, but good to keep some separation of states
				ProcessChangeState(eGPQStates.Processing);
				break;
			/**************************************************************************/
			/* State : Processing																											*/
			/* Wait while executing the associated process														*/
			/**************************************************************************/
			case eGPQStates.Processing:
				Log("AppL3",format("[GuardedProcessQueue(%s)] Processing ongoing for Item with reference %s, retry attempts =  %d",_name,_currentEntry._reference,_retryCnt));	
				// shift to the next state is done asynchronously in the notification handlers picking up the completed event
				break;
			/**************************************************************************/
			/* State : ProcessingComplete																							*/
			/* execute Ready handler & go back to processing next item								*/
			/**************************************************************************/
			case eGPQStates.ProcessingComplete:
				Log("AppL3",format("[GuardedProcessQueue(%s)] Processing ready for Item with reference %s, %d elements remaining in queue",_name,_currentEntry._reference,_buffer.len()));				
				if (typeof _currentEntry._readyhandler == "function")
					_currentEntry._readyhandler(_currentEntry,_processingResult,_retryCnt);
				else if (typeof _genericReadyHandler == "function") 
					_genericReadyHandler(_currentEntry,_processingResult,_retryCnt);
	
				_checkForEntry();
				break;

			/**************************************************************************/
			/* State : ProcessingError																							*/
			/* Check for # max retries & restart process															*/
			/**************************************************************************/
			case eGPQStates.ProcessingError:
				// check max retries
				if (_retryCnt >= _maxRetries-1)
					ProcessChangeState(eGPQStates.ProcessMaxRetries);
				else
				{
					if (_genericErrorHandler != null) 
						_genericErrorHandler(_currentEntry,_processingError);
					Log("AppL3","[GuardedProcessQueue(" + _name + ")] Error occured : " + _processingError + ", retries = " + _retryCnt);	
					_retryCnt++;
					ProcessChangeState(eGPQStates.LaunchProcessing);
				}
				break;

			/**************************************************************************/
			/* State : ProcessingTimeout																							*/
			/* Check for # max retries & restart process															*/
			/**************************************************************************/
			case eGPQStates.ProcessingTimeout:
				// check max retries
					if (_retryCnt >= _maxRetries-1)
						ProcessChangeState(eGPQStates.ProcessMaxRetries);
					else
					{
						if (_processingtimeoutHandler != null) 
							_processingtimeoutHandler(_currentEntry,_retryCnt);
						Log("AppL3",format("[GuardedProcessQueue(%s)] Timeout of %d occured waiting for processing, retries = %d",_name,_currentEntry._timeout, _retryCnt));	
						_retryCnt++;
						ProcessChangeState(eGPQStates.LaunchProcessing);
					}
				break;

			/**************************************************************************/
			/* State : ProcessMaxRetries																							*/
			/* If max retries is reached, execute max retry handler										*/
			/**************************************************************************/
			case eGPQStates.ProcessMaxRetries:
				Log("AppL3","[GuardedProcessQueue(" + _name + ")]  Max retries (" + _retryCnt + ") occured");	
				if (_maxretryHandler != null) 
						_maxretryHandler(_currentEntry,_retryCnt);
				_checkForEntry();
				break;
			default:
				break;
			}
		}
		catch(e)
		{
				ErrorLog("[GuardedProcessQueue(" + _name + "):_processSm] Exception encountered in state " + _processingSmState + " : " + e);
				if (_exceptionHandler != null) 
					_exceptionHandler(_currentEntry,_processingSmState,e);			
					// for now, simply restart after the assigned exceptionhandler
				ProcessChangeState(eGPQStates.Idle,0.1);	
		}
	}

	function StartProcessing()
	{
		_processSm();
	}

	// sets a generic handlers if none is supplied with the queued elements
	function onProcess(processhandler)
	{
		_genericProcessingHandler = processhandler;
	}

	function onReady(handler)
	{
		_genericReadyHandler = handler;
	}

	function onError(handler)
	{
		if (typeof handler == "function")
				_genericErrorHandler = handler;
		else 
			throw(format("[GuardedProcessQueue(%s)] Attempt to assign non function to _genericErrorHandler", _name));
		
	}

	function onProcessingTimeout(handler)
	{
		if (typeof handler == "function")

			_processingtimeoutHandler = handler;
		else 
			throw(format("[GuardedProcessQueue(%s)] Attempt to assign non function to _processingtimeoutHandler", _name));
	}

	function onMaxretries(handler)
	{
		if (typeof handler == "function")
			_maxretryHandler = handler;
		else 
			throw(format("[GuardedProcessQueue(%s)] Attempt to assign non function to _maxretryHandler", _name));
	}

	function onException(handler)
	{
		if (typeof handler == "function")
			_exceptionHandler = handler;
		else 
			throw(format("[GuardedProcessQueue(%s)] Attempt to assign non function to _exceptionHandler", _name));
	}

	function onMaxElements(handler)
	{
		if (typeof handler == "function")
			_maxelementHandler = handler;
		else 
			throw(format("[GuardedProcessQueue(%s)] Attempt to assign non function to _maxelementHandler", _name));
	}

	// overridden base functions
	function SendToBack(reference, data, processinghandler,readyhandler ,timeout)
	{
		if (base.ElementsWaiting() > _maxElements)
		{
			ErrorLog("[GuardedProcessQueue(" + _name + "):SendToBack] Max number of elements reached (" + _maxElements + "), ignoring");
			if (_maxelementHandler != null)
				_maxelementHandler(element);
		}
		else
		{
			base.SendToBack(QueueEntry(reference, data, processinghandler,readyhandler ,timeout));
			if (_processingSmState == eGPQStates.Idle)
				_checkForEntry();
		}
	}

	// sends new element to be processed to the front of the queue. Can be used to implement priority schemes.
	function SendToFront(reference, data, processinghandler,readyhandler, timeout)
	{
		if (base.ElementsWaiting() > _maxElements)
		{
			ErrorLog("[GuardedProcessQueue(" + _name + "):SendToBack] Max number of elements reached (" + _maxElements + "), ignoring");
			if (_maxelementHandler != null)
				_maxelementHandler(element);
		}
		else
		{
			base.SendToFront(QueueEntry(reference, data, processinghandler,readyhandler ,timeout));
			if (_processingSmState == eGPQStates.Idle)
				_checkForEntry();			
		}
	}
}
//line 15 "src\device.nut"
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

/*			testProcess.SendToBack(utilities.getNewUUID(),									// reference
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
			  5 );			// timeout*/

/**** GENERIC HANDLERS  TEST ***************************/

/*			testProcess.SendToBack("odd",format("Odd Element %d",globalcnt++),null,null);*/

/**** ERROR NOTIFICATION TEST ***************************/
			testProcess.SendToBack(utilities.getNewUUID(),									// reference
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
			  5 );			// timeout

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

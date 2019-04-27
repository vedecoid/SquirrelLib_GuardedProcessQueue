class clsGuardedProcessQueueLight extends clsQueue
{
	_name = null;
	_await = null;
	_processhandler = null;
	_timeouthandler = null;
	_locked = null;
	_locktimeout = null;
	_eventframe = null;
	_resumereason = null;
	_locktimeouttimer = null;
	_unlockevent = null;
	_overwrite = null;
	_lastexecution = null;
	_extendtimer = null;
	_maxelements = null;
	/********************************************************
	name : name of the queue
	type : eQueueType.fifo or eQueueType.lifo
	eventframe : reference to the global event framework
	timeout : (float) timeout perios in seconds after which the queue gets unblocked.
	*********************************************************/
	constructor(name,type,eventframe, timeout, maxelements = 99 )
	{
		base.constructor(type);
		_name = name;
		_locked = false;
		_unlockevent = _name + "unlock";
		_await = _processloop();
		_locktimeout = timeout;
		_eventframe = eventframe;
		_resumereason = "";
		_timeouthandler = function(){}; // assign dummy handler
	  _processhandler = function(){}; // assign dummy handler;
    _maxelements = maxelements;
		_eventframe.Subscribe(_unlockevent,"guard",function(param)
			{
				_locked = false;
				_resumereason = "Unlocked by event";
				_secureResume();
			}.bindenv(this));
	}

	// sets a generic handler if none is supplied with the queued elements
	function Setprocess(processhandler)
	{
		_processhandler = processhandler;
	}

	function ontimeout(handler)
	{
		_timeouthandler = handler;
	}

	function GetUnlockEvent()
	{
		return _unlockevent;
	}

	function StartProcessloop()
	{
		_secureResume();
	}

	// overridden base functions
	function SendToBack(name, element, handler = null)
	{
		//server.log("***************************************************Sending command to back of queue : " + element.command);
			base.SendToBack({n = name,e = element,h = handler});
			_resumereason = "Immediate processing on unlocked process";
			// to avoid getting stuck with a locked process
			if (base.ElementsWaiting() > _maxelements)
			{
			  base.Clear();
			  Unlock();
			}
			//to unlock the yield that could have been set when the queue was empty
			_secureResume();
	}

	// explicitely unlock the queue
	function Unlock()
	{
		_locked = false;
		_resumereason = "forced unlock";
		_secureResume();
	}

	function _processloop()
	{
		local toprocess;
		while(true)
		{
			yield;
			if ((_buffer.len() != 0) && (!_locked))
			{
				//server.log("[clsGuardedProcessQueue] Resumereason : " + _resumereason + " => " + _buffer.len() + " elements remaining in queue");			
				toprocess = base.Receive();
				_locked = true;
				// to avoid locking up unexpected, unlock after timeout unless the timeout has been disabled
				if (_locktimeout != 0)
					_locktimeouttimer = imp.wakeup(_locktimeout, function(){
						_locked = false;
						_secureResume();
						_resumereason = "timeout";
						_timeouthandler();
				}.bindenv(this));
				// if no specific handler is defined for this entry, then use the generic one
				_lastexecution = lib.relmsecs();
				if (toprocess.h == null)
					_processhandler(toprocess.e);
				else
					toprocess.h(toprocess.e);
			}
		}
	}

	function _secureResume()
	{
		if (_locktimeouttimer != null)
			imp.cancelwakeup(_locktimeouttimer);
		try
		{
			resume _await;
		}
		catch (e)
		{
		  server.error("[clsGuardedProcessQueue:_secureResume] Catched dead generator - restarting it...");
			lib.reboot();
			//_await = _processloop();
			//resume _await;
		}
	}
}

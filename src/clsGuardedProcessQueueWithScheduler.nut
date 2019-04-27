class clsGuardedProcessQueue extends clsQueue
{
	_name = null;
	_await = null;
	_processhandler = null;
	_timeouthandler = null;
	_locked = null;
	_locktimeout = null;
	_eventframe = null;
	_resumereason = null;
	_minperiod = null;
	_unlockevent = null;
	_overwrite = null;
	_lastexecution = null;
	_maxelements = null;
	/********************************************************
	name : name of the queue
	type : eQueueType.fifo or eQueueType.lifo
	eventframe : reference to the global event framework
	timeout : (float) timeout perios in seconds after which the queue gets unblocked.
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
	constructor(name,type,eventframe, timeout ,minperiod,overwrite ,maxelements = 99 )
	{
		base.constructor(type);
		_name = name;
		_locked = false;
		_unlockevent = _name + "unlock";
		_await = _processloop();
		_locktimeout = timeout;
		_eventframe = eventframe;
		_resumereason = "";
		_minperiod = (minperiod*1000).tointeger();
		_overwrite = overwrite;
		_maxelements = maxelements;
		_eventframe.Subscribe(_unlockevent,"guard",function(param)
		{
			local timesincelastexec = lib.relmsecs() - _lastexecution;
			// test if the last execution was minimal the throttling period ago
			// if yes, unlock the queue based on the unlockevent
			if (timesincelastexec > _minperiod)
			{
				// enough time has passed, so allow unlock of queue
				_locked = false;
				_resumereason = "unlockevent";
				// stop the timeout timer
				Timeout.Cancel("lockoutprevent_"+_name);
				_secureResume();
			}
			else // need to find a way to delay further until at least the minimal period ispassed
			{
				local timetogo = _minperiod-timesincelastexec;  // time still to go withn wait period
				OneoffTimer.Set("extend"+_name,timetogo.tofloat()/1000,function(param) {
					_locked = false;
					_resumereason = "delayed unlockevent";
					// stop the timeout timer
					Timeout.Cancel("lockoutprevent_"+_name);
					_secureResume();
				}.bindenv(this));
			}
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
		local updated = false;
		if (_overwrite == true)
		{
			for (local i = 0; i < ElementsWaiting(); i++)
			{
				// check if there is already an element with this name
				if (_buffer[i].n == name)
				{
					// overwrite with the latest request
					_buffer[i] = {n = name,e = element,h = handler};
					updated = true;
				}
			}
		}

		if (updated == false)
		{
			base.SendToBack({n = name,e = element,h = handler});
			_resumereason = "Immediate processing on unlocked process";
			if (base.ElementsWaiting() > _maxelements)
			{
			  base.Clear();
			  Unlock();
			}
			//to unlock the yield that could have been set when the queue was empty
			_secureResume();
		}
	}

	// sends new element to be processed to the front of the queue. Can be used to implement priority schemes.
	function SendToFront(name, element, handler = null)
	{
		base.SendToFront({n = name,e = element,h = handler});
		//to unlock the yield that could have been set when the queue was empty
		_resumereason = "sendtofront on unlocked process";
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
				server.log("[clsGuardedProcessQueue] Resumereason : " + _resumereason + " => " + _buffer.len() + " elements remaining in queue");			
				toprocess = base.Receive();
				_locked = true;
				// to avoid locking up unexpected, unlock after timeout unless the timeout has been disabled
				if (_locktimeout != 0)
				{
					Timeout.Set("lockoutprevent_"+_name,_locktimeout,function(param) {
						_locked = false;
						_secureResume();
						_resumereason = "timeout";
						_timeouthandler();
					}.bindenv(this));
				}
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
		try
		{
			resume _await;
		}
		catch (e)
		{
		  server.log("[clsGuardedProcessQueue:_secureResume] Catched dead generator - restarting it...");
			lib.reboot();
			//_await = _processloop();
			//resume _await;
		}
	}
}

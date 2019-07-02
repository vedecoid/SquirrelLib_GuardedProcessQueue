	enum eGPQStates {
		Init,
		WaitToProcess,
		LaunchProcessing,
		Processing,
		ProcessingComplete,
		ProcessingError,
		ProcessingTimeout,
		ProcessMaxRetries,
		Exception
	}

class GuardedProcessQueue extends Queue
{
	static VERSION = "2.0.0";

	_name = null;
	_processReadyEvent = null;
	_sequenceNr = null;
	_processHandler = null;
	_timeoutHandler = null;
	_exceptionHandler = null;
	_readyHandler = null;
	_maxretryHandler = null;
	_maxelementHandler = null;
	_errorHandler = null;
	_currentSequenceHandler = null;
	_receivedSequenceHandler = null;

	_processingPeriod = null;
	_processingResult = null;
	_processingError = null;

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
		_processReadyEvent = "GPQ_" + _name + "processready";
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
		//if (!("dataDebugAndTrace" in getroottable()))
		//		throw ("[GuardedProcessQueue-ctor " + _name + "] Cannot instantiate GuardedProcessQueue without Logging framework included");

		// event used to indicate end of processing
		gEvents.Subscribe(_processReadyEvent,"ready",function(param)
		{
			// check if response is from last issued process, if not, ignore
			try
			{
				if (getCurrentSequence(_currentItemToProcess.e) == getReceivedSequence(param.result))
				{
					if (param.error == "NoError")
					{
						_processingResult = param.result;
						_processingSmState = eGPQStates.ProcessingComplete;
					}
					else
					{
						_processingResult = param.result;
						_processingError = param.error;
						_processingSmState = eGPQStates.ProcessingError;
					}
				}
			}
			catch(e)
				{
					server.error(e);
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
					// if no specific handler is defined for this entry, then use the generic one
					if (_currentItemToProcess.h == null) 
					{
						if (_processHandler != null) 
						{
							_processHandler(_currentItemToProcess.e);
						}
					}
					else
						_currentItemToProcess.h(_currentItemToProcess.e);
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
					_readyHandler(_currentItemToProcess,_processingResult,_processingPeriod, _retryCnt);
				_processingSmState = eGPQStates.WaitToProcess
				break;

			/**************************************************************************/
			/* State : ProcessingTimeout																							*/
			/* Check for # max retries & restart process															*/
			/**************************************************************************/
			case eGPQStates.ProcessingTimeout:
				// check max retries
					if (_retryCnt >= _maxRetries-1)
						_processingSmState = eGPQStates.ProcessMaxRetries
					else
					{
						if (_timeoutHandler != null) _timeoutHandler(_currentItemToProcess.e,_timeoutPeriod,_retryCnt);
						Log("AppL3","[GuardedProcessQueue(" + _name + "):_processSm] Timeout occured waiting for processing, retries = " + _retryCnt);	
						_retryCnt++;
						_processingSmState = eGPQStates.LaunchProcessing
					}
				break;
			/**************************************************************************/
			/* State : ProcessingError																							*/
			/* Check for # max retries & restart process															*/
			/**************************************************************************/
			case eGPQStates.ProcessingError:
				// check max retries
					if (_retryCnt >= _maxRetries-1)
						_processingSmState = eGPQStates.ProcessMaxRetries
					else
					{
						if (_errorHandler != null) _errorHandler(_currentItemToProcess.e,_processingError);
						Log("AppL3","[GuardedProcessQueue(" + _name + "):_processSm] Error occured : " + _processingError + ", retries = " + _retryCnt);	
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
				if (_maxretryHandler != null) _maxretryHandler(_currentItemToProcess.e,_retryCnt);
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
			if (_exceptionHandler != null) _exceptionHandler(_currentItemToProcess.e,_processingSmState,e);
			_processingSmState = eGPQStates.Exception;
		}
		imp.wakeup(_execInterval,_processSm.bindenv(this));
	}

	function getCurrentSequence(param)
	{
		return _currentSequenceHandler(param);
	}

	function getReceivedSequence(param)
	{
		return _receivedSequenceHandler(param);
	}

	function setCurrentSequenceHandler(handler)
	{
		_currentSequenceHandler = handler;
	}

		function setReceivedSequenceHandler(handler)
	{
		_receivedSequenceHandler = handler;
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

	function onError(handler)
	{
		_errorHandler = handler;
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

	function GetReadyEvent()
	{
		return _processReadyEvent;
	}

	// for backward compatibility with existing code
	function GetUnlockEvent()
	{
		return _processReadyEvent;
	}
	

	function GetErrorEvent()
	{
		return _processErrorEvent;
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

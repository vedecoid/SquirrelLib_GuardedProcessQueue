@include once "github:vedecoid/SquirrelLib_Queue/src/Queue.lib.nut@V2.0.0" 


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
	static VERSION = "3.0.0";

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

	function NotifyProcessingBusy()
  {
		_cancelTimeoutProtection();
		ProcessChangeState(eGPQStates.LaunchProcessing,1);		
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
			Log("debug",format("[GuardedProcessQueue(" + _name + ")] Changing state to %s",state));
			_processingSmState = state;
			return imp.wakeup(0,function(){_processSm();}.bindenv(this));
		}
		else 
		{

			return imp.wakeup(delay,function(){
					Log("debug",format("[GuardedProcessQueue(" + _name + ")] Changing state to %s with delay %d",state,delay));
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
					//server.log("Cancelling lock-up protection")
			imp.cancelwakeup(_timeoutwakeup);		
			_timeoutwakeup = null;
		}
	}

	function _startTimeoutProtection()
	{
		//server.log("Starting lock-up protection")
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
				if (typeof _currentEntry._processinghandler == "function") 
				{
					_currentEntry._processinghandler(_currentEntry);
				}
				
				if (typeof _genericProcessingHandler == "function") 
						_genericProcessingHandler(_currentEntry);

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
				
				if (typeof _genericReadyHandler == "function") 
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

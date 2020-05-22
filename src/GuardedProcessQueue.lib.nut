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

class GuardedProcessQueue extends Queue
{
	static VERSION = "2.0.0";

	_name = null;
	_processHandler = null;
	_processingtimeoutHandler = null;
	_queueingtimeoutHandler = null;
	_exceptionHandler = null;
	_readyHandler = null;
	_maxretryHandler = null;
	_maxelementHandler = null;
	_errorHandler = null;

	_processingResult = null;
	_processingError = null;
	_processingTimeout = null;
	_queueingTimeout = null;

	_maxElements = null;
	_maxRetries = null;
	_retryCnt = null;
	_processingSmState = null;
	_timeoutMaxPeriod = null;

	_currentItemToProcess = null;
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
		_name = name;
		_maxElements = maxelements;
		_processingSmState = eGPQStates.Idle;
		_retryCnt = 0;
		_timeoutMaxPeriod = maxprocessingtimeout;
		_maxRetries = maxretries;
	}

 	function NotifyProcessingReady(param)
  {
		_processingResult = param;
		_cancelTimeoutProtection();
		ProcessChangeState(eGPQStates.ProcessingComplete);
	}

	function NotifyProcessingError(param)
  {
		_processingError = param;
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
					Log("debug",format("Changing state to %s",state));
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
			imp.cancelwakeup(_timeoutwakeup);		
			_timeoutwakeup = null;
		}
	}

	function _startTimeoutProtection()
	{
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
				_currentItemToProcess = base.Receive();
				_retryCnt = 0;			
				// change to the timeout state after the timeout period. This is needed in case the queue entry fails to notify timeout
				_startTimeoutProtection();

				// if no specific handler is defined for this entry, then use the generic one
				if (_currentItemToProcess.h == null) 
				{
					if (typeof _processHandler == "function") 
						_processHandler(_currentItemToProcess.e);
				}
				else
					_currentItemToProcess.h(_currentItemToProcess.e);
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
				if (_currentItemToProcess.h == null) 
				{
					if (typeof _processHandler == "function") 
						_processHandler(_currentItemToProcess.e);
				}
				else
					_currentItemToProcess.h(_currentItemToProcess.e);
					// not really needed, but good to keep some separation of states
				ProcessChangeState(eGPQStates.Processing);
				break;
			/**************************************************************************/
			/* State : Processing																											*/
			/* Wait while executing the associated process														*/
			/**************************************************************************/
			case eGPQStates.Processing:
				Log("AppL3","[GuardedProcessQueue(" + _name + "):_processSm]  Processing Item /" + _currentItemToProcess.n + "/, " +  _buffer.len() + " elements remaining in queue");	
				// shift to the next state is done asynchronously in the notification handlers picking up the completed event
				break;
			/**************************************************************************/
			/* State : ProcessingComplete																							*/
			/* execute Ready handler & go back to processing next item								*/
			/**************************************************************************/
			case eGPQStates.ProcessingComplete:
				if (typeof _currentItemToProcess.r == "function")
					_currentItemToProcess.r(_currentItemToProcess,_processingResult,_retryCnt);
				else if (typeof _readyHandler == "function") 
					_readyHandler(_currentItemToProcess,_processingResult,_retryCnt);
	
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
						if (_errorHandler != null) 
							_errorHandler(_currentItemToProcess.e,_processingError);
						Log("AppL3","[GuardedProcessQueue(" + _name + "):_processSm] Error occured : " + _processingError + ", retries = " + _retryCnt);	
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
							_processingtimeoutHandler(_currentItemToProcess.e,_processingTimeout,_retryCnt);
						Log("AppL3",format("[GuardedProcessQueue(%s):_processSm] Timeout of %d occured waiting for processing, retries = %d",_name,_processingTimeout, _retryCnt));	
						_retryCnt++;
						ProcessChangeState(eGPQStates.LaunchProcessing);
					}
				break;

			/**************************************************************************/
			/* State : ProcessMaxRetries																							*/
			/* If max retries is reached, execute max retry handler										*/
			/**************************************************************************/
			case eGPQStates.ProcessMaxRetries:
				Log("AppL3","[GuardedProcessQueue(" + _name + "):_processSm]  Max retries (" + _retryCnt + ") occured");	
				if (_maxretryHandler != null) 
						_maxretryHandler(_currentItemToProcess.e,_retryCnt);
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
					_exceptionHandler(_currentItemToProcess.e,_processingSmState,e);			
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

	function onProcessingTimeout(handler)
	{
		_processingtimeoutHandler = handler;
	}

	function onQueueingTimeout(handler)
	{
		_queueingtimeoutHandler = handler;
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

	// overridden base functions
	function SendToBack(name, element, processinghandler,onreadyhandler )
	{
		if (base.ElementsWaiting() > _maxElements)
		{
			ErrorLog("[GuardedProcessQueue(" + _name + "):SendToBack] Max number of elements reached (" + _maxElements + "), ignoring");
			if (_maxelementHandler != null)
				_maxelementHandler(element);
		}
		else
		{
			base.SendToBack({n = name,e = element,h = processinghandler,r = onreadyhandler});
			if (_processingSmState == eGPQStates.Idle)
				_checkForEntry();
		}
	}

	// sends new element to be processed to the front of the queue. Can be used to implement priority schemes.
	function SendToFront(name, element, processinghandler,onreadyhandler)
	{
		if (base.ElementsWaiting() > _maxElements)
		{
			ErrorLog("[GuardedProcessQueue(" + _name + "):SendToBack] Max number of elements reached (" + _maxElements + "), ignoring");
			if (_maxelementHandler != null)
				_maxelementHandler(element);
		}
		else
		{
			base.SendToFront({n = name,e = element,h = processinghandler,r = onreadyhandler});
			if (_processingSmState == eGPQStates.Idle)
				_checkForEntry();			
		}
	}
}

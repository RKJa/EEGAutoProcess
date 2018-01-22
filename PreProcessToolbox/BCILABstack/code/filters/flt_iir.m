function [signal,state] = flt_iir(varargin)
% Filter a continuous data set by a digital IIR lowpass/highpass/bandpass/bandstop filter.
% [Signal,State] = flt_iir(Signal, Frequencies, Mode, Type, Attenuation, Ripple, State)
%
% Digital IIR filters [1] are efficient for both offline and online analysis. They distort the
% signal, but introduce relatively low delay (comparable to minimum-phase FIR filters), so that the
% latency of a BCI is only marginally increased by adding an IIR filter. However, IIR filters are
% numerically sensitive (they can "blow up"), and therefore, extreme frequency responses (e.g.,
% low-frequency 'brickwall' filters) can often not be satisfactorily implemented. In these cases,
% FIR or FFT filters (flt_fir or flt_select, respectively) can be used as a fall-back.
%
% In:
%   Signal       :   continuous data set to be filtered
%
%   Frequencies  :   frequency specification:
%                    * for a low/high-pass filter: [transition-start, transition-end],in Hz
%                    * for a band-pass/stop filter: [low-transition-start,
%                      low-transition-end, hi-transition-start, hi-transition-end], in Hz
%                    * for a free-form filter: [freq,freq,freq,...; amplitude,amplitude,amplitude,...]
%
%   Mode         :   filter mode, 'bp' for bandpass, 'hp' for highpass, 'lp' for lowpass,
%                    'bs' for bandstop, 'ff' for free-form (default: 'bp')
%
%   Type         :   'butter' for a Butterworth filter -- pro: flat response overall; con: slow
%                             attenuation (default)
%                    'cheb1' for a Chebychev Type I filter -- pro: steep attennuation; con:
%                            strong passband ripple
%                    'cheb2' for a Chebychev Type II filter -- pro: flat
%                            passband response; con: slower
%                            attenuation than cheb1
%                    'ellip' for an Elliptic filter -- pro: steepest rolloff, lowest latency;
%                            con: passband ripple
%                    'yulewalk' for a Yule-Walker filter -- allows for free-form designs, but can 
%                            be erratic (automatic for free-form mode)
%
%   Attenuation  :   stop-band attenuation, in db, default: 50
%
%   Ripple       :   maximum allowed pass-band ripple, in db, default: 3
%
%   ChunkLength : Maximum chunk length. Process the data in chunks of no larger than this (to avoid
%                 memory limitations). (default: 50000)
%
%   YuleWalkerOrder : Filter order to use for Yule-Walker design. Only used when that design is chosen.
%
%   State        :   previous filter state, as obtained by a previous execution of flt_iir on an
%                    immediately preceding data set (default: [])
%
% Out:
%   Signal       :  filtered, continuous EEGLAB data set
%
%   State        :  state of the filter, can be used to continue on a subsequent portion of the data
%
% Examples:
%   % apply a 7-30 Hz IIR filter with generous transition regions
%   eeg = flt_iir(eeg,[5 10 25 35])
%
%   % apply a 1Hz highpass filter with 1Hz transition bandwidth
%   eeg = flt_iir(eeg,[0.5 1.5],'highpass')
%
%   % apply a 45-55 Hz notch filter for east european line noise
%   eeg = flt_iir(eeg,[40 45 55 60],'bandstop')
%
%   % apply a 45-55 Hz notch filter with Chebychev Type I design, passing all arguments by name
%   eeg = flt_iir('Signal',eeg,'Frequencies',[40 45 55 60],'Mode','bandstop','Type','chebychev1')
%   
%
% References:
%  [1] T. W. Parks and C. S. Burrus, "Digital Filter Design",
%      John Wiley & Sons, 1987, chapter 7.
%
% See also:
%   butter, cheby1, cheby2, ellip, dfilt, filter
%
% TODO:
%   Current filter design can flip signal sign, fix.
%
% Notes:
%   Requires the Signal Processing toolbox.
%
%                                Christian Kothe, Swartz Center for Computational Neuroscience, UCSD
%                                2010-04-17

% flt_iir_version<1.01> -- for the cache

if ~exp_beginfun('filter') return; end

% running after the FIR can improve numeric stability; makes no sense on epoched data
declare_properties('name','IIRFilter', 'cannot_follow','set_makepos', 'independent_channels',true, 'independent_trials',true);

arg_define(varargin, ...
    arg_norep({'signal','Signal'}), ...
    arg({'fspec','Frequencies','f'}, [], [], 'Frequency specification of the filter. For a low/high-pass filter, this is: [transition-start, transition-end], in Hz and for a band-pass/stop filter, this is: [low-transition-start, low-transition-end, hi-transition-start, hi-transition-end], in Hz. For a free-form filter, this is a 2d matrix of the form [frequency,frequency,frequency, ...; amplitude, amplitude, amplitude, ...].'), ...
    arg({'fmode','Mode'}, 'bandpass', {'bandpass','highpass','lowpass','bandstop','freeform'}, 'Filtering mode. Determines how the Frequencies parameter is interpreted.'), ...
    arg({'ftype','Type'},'butterworth', {'butterworth','chebychev1','chebychev2','elliptic','yule-walker'}, 'Filter type. Butterworth has a flat response overall but a slow/gentle rolloff. Chebychev Type I has a steep rolloff, but strong passband ripples. Chebychev Type II has a flat passband response, but a slower rolloff than Type I. The elliptic filter has the steepest rolloff (or lowest latency at comparable steepness) but passband rippling. Yule-walker is enabled implicitly for free-form filter design.'), ...
    arg({'atten','Attenuation'}, 60, [0 180], 'Minimum signal attenuation in the stop band. In db.'),...
    arg({'ripple','Ripple'}, 0.1, [0 60], 'Maximum peak-to-peak ripple in pass band. In db.'), ...
    arg({'chunk_length','ChunkLength'},50000,[], 'Maximum chunk length. Process the data in chunks of no larger than this (to avoid memory limitations).','guru',true), ...
    arg({'yulewalk_order','YulewalkerOrder'},8,[], 'Order for Yule-Walker design. Only used if that design is selected.','guru',true), ...
    arg_nogui({'state','State'}));

if signal.trials > 1
    error('flt_iir is supposed to be applied to continuous (non-epoched) data.'); end

if isempty(state)
    % compute filter parameters
    f = 2*fspec/signal.srate;
    if length(f) < 4 && any(strcmp(fmode,{'bp','bs'}))
        error('For an IIR bandpass/bandstop filter, four frequencies must be specified.'); end
    switch fmode
        case {'bandpass','bp'}
            [Wp,Ws,label] = deal(f([2,3]),f([1,4]),{});
        case {'bandstop','bs'}
            [Wp,Ws,label] = deal(f([1,4]),f([2,3]),{'stop'});
        case {'lowpass','lp'}
            [Wp,Ws,label] = deal(f(1),f(2),{'low'});
        case {'highpass','hp'}
            [Wp,Ws,label] = deal(f(2),f(1),{'high'});
        case {'freeform','ff'}
            [F,M] = deal([0 2*fspec(1,:)/signal.srate 1],fspec(2,[1 1:end end]));
            ftype = 'yulewalk';
        otherwise
            error(['Unrecognized filter mode specified: ' hlp_tostring(fmode)]);
    end

    % compute filter coefficients
    switch ftype
        case {'butterworth','butt'}
            [n,Wn] = hlp_diskcache('filterdesign',@buttord,Wp,Ws,ripple,atten);
            [z,p,k] = hlp_diskcache('filterdesign',@butter,n,Wn,label{:});
        case {'chebychev1','cheb1'}
            [n,Wn] = hlp_diskcache('filterdesign',@cheb1ord,Wp,Ws,ripple,atten);
            [z,p,k] = hlp_diskcache('filterdesign',@cheby1,n,ripple,Wn,label{:});
        case {'chebychev2','cheb2'}
            [n,Wn] = hlp_diskcache('filterdesign',@cheb2ord,Wp,Ws,ripple,atten);
            [z,p,k] = hlp_diskcache('filterdesign',@cheby2,n,atten,Wn,label{:});
        case {'elliptic','ellip'}
            [n,Wn] = hlp_diskcache('filterdesign',@ellipord,Wp,Ws,ripple,atten);
            [z,p,k] = hlp_diskcache('filterdesign',@ellip,n,ripple,atten,Wn,label{:});
        case {'yule-walker','yulewalk'}
            [b,a] = hlp_diskcache('filterdesign',@yulewalk,yulewalk_order,F,M);
            [z,p,k] = hlp_diskcache('filterdesign',@tf2zp,b,a);
        otherwise 
            error(['Unrecognized filter type specified: ' hlp_tostring(ftype)]);
    end
    [sos,g] = hlp_diskcache('filterdesign',@zp2sos,z,p,k);
    
   % initialize state
    for fld = utl_timeseries_fields(signal)
        state.(fld{1}).sos = sos;
        state.(fld{1}).g = g;
        state.(fld{1}).zi = repmat({[]},1,size(sos,1));
    end
end

for fld = utl_timeseries_fields(signal)
    field = fld{1};
    if isfield(signal,field) && ~isempty(signal.(field)) && ~isequal(signal.(field),1)
        % apply filter for each section
        for s = 1:size(state.(field).sos,1)
            [signal.(field),state.(field).zi{s}] = filter(state.(field).sos(s,1:3),state.(field).sos(s,4:6),double(signal.(field)),state.(field).zi{s},2); end
        % apply gain
        signal.(field) = signal.(field)*state.(field).g;
    end
end

exp_endfun;
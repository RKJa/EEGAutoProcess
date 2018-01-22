function signal = flt_rescale(varargin)
% Rescale raw data by a factor.
% Tim Mullen, SCCN/INC

if ~exp_beginfun('filter') return; end

declare_properties('name','Rescale','precedes','flt_resample','independent_channels',true, 'independent_trials',true);


arg_define(varargin, ...
    arg_norep({'signal','Signal'}), ...
    arg({'scaleFactor','ScaleFactor'},1,[],'Scaling factor'));

signal.data = scaleFactor*signal.data;

exp_endfun;
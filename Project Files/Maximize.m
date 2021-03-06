%% AE 4451 Jet & Rocket Propulsion Project
% 10/26/2018
% Authors: Loren Isakson, Brandon Campanile, Matthew Yates
%
% The following function uses MatLab's GlobalSearch function to find the
% global maximum ST subject to the nonlinear constraints below. GlobalSearch
% itself calls fmincon with the sqp algorithm.
% 
% The fuction can be called directly with user inputs, but we recommend
% using the GUI included.
%
%

%%

function output = Maximize(ab, eType, Nmix, Ta, Pa, Pf, M, Prf, Prc, Prb, Prab, Prnm, beta, ~, ~, ~, Tomax, Tmax_ab, MW, eff, y, HVf)

T = 0; % we dont want table output at this point

if ab % w/ afterburner
        % [fuel-air ratio, afterburner fuel-air ratio, bleed ratio]
        lb = [.001, .0005, 0]; % lower bound
        ub = [.1, .1, .12];        % upper bound
        x0 = [.05, .05, .05]; % starting point
else
        lb = [.001, 0, 0];
        ub = [.1, 0, .12];
        x0 = [.05, 0, .05];
end

func = @(x)singleOut(x, T, eType, Nmix, Ta, Pa, Pf, M, Prf, Prc, Prb, Prab, Prnm, beta, Tomax, Tmax_ab, MW, eff, y, HVf);

nlc = @(x)nonlcon(x, T, eType, Nmix, Ta, Pa, Pf, M, Prf, Prc, Prb, Prab, Prnm, beta, Tomax, Tmax_ab, MW, eff, y, HVf);

opt = optimoptions('fmincon','Algorithm','sqp','MaxIterations',400);

problem = createOptimProblem('fmincon','objective', func,'x0',x0,'lb',lb,'ub',ub,'nonlcon', nlc, 'options',opt);

gs=GlobalSearch('Display','off');

[ST_max,~,exitflag] = run(gs,problem);

if exitflag<=0 % if the function could not converge and error message will be thrown
    err=true;
else
    err=false;
end

output = {ST_max, err};

end

function ST = singleOut(x, T, eType, Nmix, Ta, Pa, Pf, M, Prf, Prc, Prb, Prab, Prnm, beta, Tomax, Tmax_ab, MW, eff, y, HVf)
f = x(1);
fab = x(2);
b = x(3);
output = JetPro_Project(T, eType, Nmix, Ta, Pa, Pf, M, Prf, Prc, Prb, Prab, Prnm, beta, b, f, fab, Tomax, Tmax_ab, MW, eff, y, HVf);
ST = -output(1); % we want to maximize ST (minimize negative ST)
end

function [g,ceq] = nonlcon(x, T, eType, Nmix, Ta, Pa, Pf, M, Prf, Prc, Prb, Prab, Prnm, beta, Tomax, Tmax_ab, MW, eff, y, HVf)
R=8314; % universal gas constant
CB=700; % kelvin
bmax=.12; % maximum compressor bleed
f = x(1);
fab = x(2);
b = x(3);

out2 = JetPro_Project(T, eType, Nmix, Ta, Pa, Pf, M, Prf, Prc, Prb, Prab, Prnm, beta, b, f, fab, Tomax, Tmax_ab, MW, eff, y, HVf);

Cp1 = y(4)*(R/MW(4))/(y(4)-1);
Cp2 = y(8)*(R/MW(8))/(y(8)-1);
Tmax = Tomax + CB*(b/bmax)^0.5; % maximum temperature correction due to compressor bleed
fmax = (1-b)*(1-out2(3)/Tmax)/(eff(4)*HVf/Cp1/Tmax - 1);

% Constraints
g(1) = f - fmax; % f <= fmax
g(2) = (out2(3)+f*HVf/Cp1)/(1+f-b) - Tmax; % Tb <= Tmax
if fab>0
    g(3) = (out2(4) + (f+fab)*HVf/Cp2)/(1+f+fab) - Tmax_ab; % Tab <= Tmaxab
    g(4) = fab - (1+fmax)*(Tmax_ab/out2(4) - 1)/((eff(7)*HVf/Cp2 - Tmax_ab)/out2(4)); % fab <= fmaxab
else
    g(3)=0; % fmincon needs constraints to be the same length between iterations
    g(4)=0;
end

ceq = [];
end
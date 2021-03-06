%% AE 4451 Jet & Rocket Propulsion Project
% 10/26/2018
% Authors: Loren Isakson, Brandon Campanile, Matthew Yates
%
% The following function uses MatLab's GlobalSearch function to find the
% global minimum TSFC subject to the nonlinear constraints below. GlobalSearch
% itself calls fmincon with the sqp algorithm.
% 
% The fuction can be called directly with user inputs, but we recommend
% using the GUI included.
%
%

%%

function output = optimization(ST, eType, Nmix, Ta, Pa, Pf, M, ~, ~, Prb, Prab, Prnm, ~, ~, ~, ~, Tomax, Tmax_ab, MW, eff, y, HVf)

T = 0; % we dont want table output at this point
TSFC = zeros(1,2);
minVar = cell(1,2);
exitflags = cell(1,2);

for ab=0:1 % the code is run with and without an afterburner, the minimum being selected
    if strcmp(eType, 'Turbofan')
        if ab % w/ afterburner
            % [bypass ratio, fan pressure ratio, compressor pressure ratio, fuel-air ratio, afterburner fuel-air ratio, bleed ratio]
            lb = [0.001, 1.1, 20, .001, .0005, 0]; % lower bound
            ub = [10, 1.5, 54.545455, .1, .1, .12];        % upper bound
            x0 = [8, 1.25, 45, .03, .03, .08]; % starting point
        else
            lb = [.001, 1.1, 20, .001, 0, 0];
            ub = [10, 1.5, 54.545455, .1, 0, .12];
            x0 = [8, 1.25, 45, .03, 0, .08];
        end
    elseif strcmp(eType, 'Turbojet')
        if ab % w/ afterburner
            % compressor pressure ratio, fuel air ratio, afterburner fuel air ratio, bleed ratio
            lb = [5, .001, .0005, 0];
            ub = [54.545455, .1, .1, .12];
            x0 = [20, .02, .01, .08];
        else
            lb = [5, .001, 0, 0];
            ub = [54.545455, .1, 0, .12];
            x0 = [20, .02, 0, .08];
        end
    else % ramjet
        if ab % w/ afterburner
            % fuel air ratio, afterburner fuel air ratio, bleed ratio
            lb = [.001, .0005, 0];
            ub = [.1, .1, .12];
            x0 = [.03, .03, .08];
        else
            lb = [.001, 0, 0];
            ub = [.1, 0, .12];
            x0 = [.03, 0, .08];
        end
    end
    
    func = @(x)singleOut(x, T, eType, Nmix, Ta, Pa, Pf, M, Prb, Prab, Prnm, Tomax, Tmax_ab, MW, eff, y, HVf);
    
    nlc = @(x)nonlcon(x, T, ST, eType, Nmix, Ta, Pa, Pf, M, Prb, Prab, Prnm, Tomax, Tmax_ab, MW, eff, y, HVf);
    
    opt = optimoptions('fmincon','Algorithm','sqp','MaxIterations',400);
    
    problem = createOptimProblem('fmincon','objective', func,'x0',x0,'lb',lb,'ub',ub,'nonlcon', nlc, 'options',opt);
    
    gs=GlobalSearch('Display','off');

    [b_min,~,exitflag] = run(gs,problem);
    
    exitflags{ab+1}=exitflag;
    
    minVar{ab+1} = b_min;
    
    TSFC(ab+1) = singleOut(b_min, T, eType, Nmix, Ta, Pa, Pf, M, Prb, Prab, Prnm, Tomax, Tmax_ab, MW, eff, y, HVf);
end

[~,G]=min(TSFC); % select minimum w/ or w/out afterburner

if exitflags{1}<=0 && exitflags{2}<=0 % if no solutions found, an error message will be thrown.
   err=true;
else
    err=false;
end

Values = minVar{G};

output = {Values, err};

end

function TSFC4 = singleOut(x, T, eType, Nmix, Ta, Pa, Pf, M, Prb, Prab, Prnm, Tomax, Tmax_ab, MW, eff, y, HVf)
% fmincon needs a function with a single output. This function reduces the
% JetPro_Project function to the desired single output
Prf = 1;
Prc = 1;
beta = 0;
if strcmp(eType,'Turbofan')
    beta = x(1);
    Prf = x(2);
    Prc = x(3);
    f = x(4);
    fab = x(5);
    b = x(6);
elseif strcmp(eType,'Turbojet')
    Prc = x(1);
    f = x(2);
    fab = x(3);
    b = x(4);
else
    f = x(1);
    fab = x(2);
    b = x(3);
end
output = JetPro_Project(T, eType, Nmix, Ta(1), Pa(1), Pf, M(1), Prf, Prc, Prb, Prab, Prnm, beta, b, f, fab, Tomax, Tmax_ab, MW, eff, y, HVf);
TSFC2 = output(2);

output2 = JetPro_Project(T, eType, Nmix, Ta(2), Pa(2), Pf, M(2), Prf, Prc, Prb, Prab, Prnm, beta, b, f, fab, Tomax, Tmax_ab, MW, eff, y, HVf);
TSFC3 = output2(2);
TSFC4 = TSFC2 + TSFC3; % We want to minimize the TSFC for both flight conditions.
end

function [g,ceq] = nonlcon(x, T, ST, eType, Nmix, Ta, Pa, Pf, M, Prb, Prab, Prnm, Tomax, Tmax_ab, MW, eff, y, HVf)
R=8314; % universal gas constant
CB=700; % kelvin
bmax=.12; % max bleed ratio

if strcmp(eType,'Turbofan')
    beta = x(1);
    Prf = x(2);
    Prc = x(3);
    f = x(4);
    fab = x(5);
    b = x(6);
elseif strcmp(eType,'Turbojet')
    Prc = x(1);
    f = x(2);
    fab = x(3);
    b = x(4);
    Prf = 1;
    beta = 0;
else
    f = x(1);
    fab = x(2);
    b = x(3);
    Prf = 1;
    Prc = 1;
    beta = 0;
end

out2 = JetPro_Project(T, eType, Nmix, Ta(1), Pa(1), Pf, M(1), Prf, Prc, Prb, Prab, Prnm, beta, b, f, fab, Tomax, Tmax_ab, MW, eff, y, HVf);

Cp1 = y(4)*(R/MW(4))/(y(4)-1);
Cp2 = y(8)*(R/MW(8))/(y(8)-1);
Tmax = Tomax + CB*(b/bmax)^0.5; % max temperature correction due to compressor bleed cooling
fmax = (1-b)*(1-out2(3)/Tmax)/(eff(4)*HVf/Cp1/Tmax - 1);

% Constraints:
g(1) = Prc - 60/Prf; % prc<=60/prf
g(2) = f - fmax; % f <= fmax
g(3) = (out2(3)+f*HVf/Cp1)/(1+f-b) - Tmax; % Tb <= Tmax
g(4) = ST(1)*1000-out2(1); % ST >= STdesired
if fab>0
    g(5) = (out2(4) + (f+fab)*HVf/Cp2)/(1+f+fab) - Tmax_ab; % Tab <= Tmaxab
    g(6) = fab - (1+fmax)*(Tmax_ab/out2(4) - 1)/((eff(7)*HVf/Cp2 - Tmax_ab)/out2(4)); % fab <= fmaxab
else
    g(5)=0; % fmincon needs constraints to be the same length between iterations
    g(6)=0;
end

out3 = JetPro_Project(T, eType, Nmix, Ta(2), Pa(2), Pf, M(2), Prf, Prc, Prb, Prab, Prnm, beta, b, f, fab, Tomax, Tmax_ab, MW, eff, y, HVf);

g(7) = (out3(3)+f*HVf/Cp1)/(1+f-b) - Tmax; % Tb <= Tmax
g(8) = ST(2)*1000-out3(1); % ST >= STdesired
if fab>0
    g(9) = (out3(4) + (f+fab)*HVf/Cp2)/(1+f+fab) - Tmax_ab; % Tab <= Tmaxab
    g(10) = fab - (1+fmax)*(Tmax_ab/out3(4) - 1)/((eff(7)*HVf/Cp2 - Tmax_ab)/out3(4)); % fab <= fmaxab
else
    g(9)=0;
    g(10)=0;
end

ceq = [];
end
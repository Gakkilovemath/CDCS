function [stop,info,log,opts] = checkConvergence(hatu,u,v,uold,iter,admmtime,opts,At,b,c,others,log)

% CHECKCONVERGENCE primal/dual infeasible
% Problem codes
%
% 0: converged
% 1: primal infeasible
% 2: dual infeasible
% 3: max number of iterations reached

stop = false;
info.problem = 3;

if u.tau > 0   %% feasible problem
    x = u.x./u.tau;
    y = u.y./u.tau;
    dcost = (b.'*y)/opts.scaleFactors.sc_cost;        %% dual cost
    pcost = (c.'*x)/opts.scaleFactors.sc_cost;        %% primal cost
    
%     % ======================================================================== %
%     % Scaled residuals, unscaled cost
%     presi = norm(At.'*x - b,'fro')./max([1,opts.nAt,opts.nb]);
%     gap   = abs(pcost - dcost)/(1 + abs(pcost) + abs(dcost));
%     
%     % GF: I think the dual residual is wrong, will need a factor of \rho for the
%     %     variable v.x because in the code v.x is the unscaled multiplier while
%     %     in the algorithm by O'Donoghue et al it is scaled.
%     % Uncomment the first line if v is the unscaled multipler, the second one if
%     % v is the scaled multiplier.
%     %     dresi = norm((At*y + (v.x./u.tau)./opts.rho- c),'fro')./max([1,opts.nAt,opts.nc]);
%     dresi = norm((At*y + (v.x./u.tau) - c),'fro')./max([1,opts.nAt,opts.nc]);
%     % ======================================================================== %
    
    % Residuals before rescaling (O'Donoghue et al, Section 5)
    % Use same normalization as O'Donoghue et al
    pk  = (At.'*x - b).*opts.scaleFactors.E;
    presi = ( norm(pk,'fro')./(1+opts.nb_init) ) / opts.scaleFactors.sc_b;
    dk  = (At*y + (v.x./u.tau) - c).*opts.scaleFactors.D;
    dresi = ( norm(dk,'fro')./(1+opts.nc_init) ) / opts.scaleFactors.sc_c;
    gap = abs(pcost - dcost)/(1 + abs(pcost) + abs(dcost));
    
    
    if max([presi,dresi,gap]) < opts.relTol
        info.problem = 0;
        stop = true;
    end
    
    % ======================================================================== %
    % GF: the entire algorithm is independent of \rho, so there is no point in
    %     updating it.
    % ======================================================================== %
    %     % adpative penalty?
    %     % GF: Only adapt penalty if not stopping after this iteration...
    %     if opts.adaptive && ~stop
    %
    %         % standard ADMM residual according to Boyd's paper
    %         utmp = vertcat(u.x,u.y,u.tau);
    %         vtmp = vertcat(v.x,v.y,v.kappa);
    %         hatutmp = vertcat(hatu.x,hatu.y,hatu.tau);
    %         uoldtmp = vertcat(uold.x,uold.y,uold.tau);
    %
    %         utmp_norm = norm(utmp,'fro');
    %         r = norm(utmp-hatutmp,'fro')./max(utmp_norm,norm(hatutmp,'fro'));
    %         s = opts.rho*norm(utmp-uoldtmp,'fro')./max(utmp_norm,norm(vtmp,'fro'));
    %
    %         % Update ADMM penalty parameter
    %         opts = updatePenalty(opts,r,s,iter);  % something is wrong with this option?
    %
    %     end
    % ======================================================================== %
    
else % infeasible or unbounded problem?
    pinfIndex = b.'*u.y;  % index of certificating primal infesibility
    dinfIndex = -c.'*u.x; % index of certificating dual infesibility
    if dinfIndex > 0    % dual infeasible
        % Scaled variables
%         pfeas    = norm(At'*u.x,'fro');
%         pfeasTol = dinfIndex/opts.nc*opts.relTol;
        % Original variables
        pfeas    = norm( (At'*u.x).*opts.scaleFactors.E ,'fro');
        pfeasTol = dinfIndex/opts.nc_init/opts.scaleFactors.sc_c*opts.relTol;
        if pfeas <= pfeasTol  %% a point x that certificates dual infeasiblity
            info.problem = 2;
            stop = true;
        end
    end
    if pinfIndex > 0   % primal infeasible
        % ======================================================================== %
        % Scaled variables
        % GF: uncomment the first line if v is the unscaled multiplier, the
        %     second one if v is the scaled multiplier
        % dfeas    = norm(At*u.y+v.x./opts.rho,'fro');
        % dfeas    = norm(At*u.y+v.x,'fro');
        % dfeasTol = pinfIndex/opts.nb*opts.relTol;
        % ======================================================================== %
        % Original variables
        dfeas    = norm( (At*u.y+v.x).*opts.scaleFactors.D ,'fro');
        dfeasTol = pinfIndex/opts.nb_init/opts.scaleFactors.sc_b*opts.relTol;
        if dfeas <= dfeasTol  %% a point y that certificates primal infeasiblity
            info.problem = 1;
            stop = true;
        end
    end
    
    % value
    presi = NaN;
    dresi = NaN;
    pcost = NaN;
    dcost = NaN;
    gap   = NaN;
end

%progress message
if opts.verbose && (iter == 1 || ~mod(iter,opts.dispIter) || stop)
    fprintf('%5d | %7.2e | %7.2e | %9.2e | %9.2e | %8.2e | %8.2e | %8.2e |\n',...
        iter,presi,dresi,pcost,dcost,gap, opts.rho,toc(admmtime))
end

% log information
% Use preallocation for speed
if iter==1
	% Much faster preallocation method
    %cc = cell(opts.maxIter,1);
    %log = struct('pres',cc,'dres',cc,'cost',cc,'dcost',cc);
    log.dcost = zeros(opts.maxIter,1);
    log.gap   = zeros(opts.maxIter,1);
    
    % Old
    %     [log(1:opts.maxIter,1).pres] = deal(0);
    %     [log(1:opts.maxIter,1).dres] = deal(0);
    %     [log(1:opts.maxIter,1).cost] = deal(0);
    %     [log(1:opts.maxIter,1).dcost] = deal(0);
end
log.pres(iter)  = presi;
log.dres(iter)  = dresi;
log.cost(iter)  = pcost;   %% use primal cost
log.dcost(iter) = dcost;
log.gap(iter)   = gap;

% end main
end

% % ============================================================================ %
% % Nested functions
% % ============================================================================ %
%
% function opts = updatePenalty(opts,pres,dres,iter)
% % Update penaly
%
%     persistent itPinf itDinf
%     if iter == 1 || isempty(itPinf) || isempty(itDinf)
%         % initialize persistent iteration counters when entering for the first
%         % time (persistent variables are empty and not zero when declared)
%         itPinf = 0; % number of iterations for which pinf/dinf <= eta
%         itDinf = 0; % number of iterations for which pinf/dinf > eta
%     end
%
%     if opts.adaptive
%         resRat = pres/dres;
%         if resRat >= opts.mu
%             itPinf = itPinf+1;
%             itDinf = 0;
%             if itPinf >= opts.rhoIt
%                 % ratio of pinf and dinf remained large for long => rescale rho
%                 itPinf = 0;
%                 opts.rho = min(opts.rho*opts.tau, opts.rhoMax);
%             end
%         elseif 1/resRat >= opts.mu
%             itDinf = itDinf+1;
%             itPinf = 0;
%             if itDinf >= opts.rhoIt
%                 % ratio of pinf and dinf remained small for long => rescale rho
%                 itDinf = 0;
%                 opts.rho = max(opts.rho/opts.tau, opts.rhoMin);
%             end
%         end
%     end
%
% end


function [ x_pts_array, tau_pts_array, alpha_pts_array ] = particle_flow_PE_filter( init_x_pts, init_tau_pts, init_alpha_pts, times, observs, params, h_trans, h_obs )
%PARTICLE_FLOW_FILTER Run a particle flow filter for an AR(1) process with
%parameter learning

fprintf(1, '\n\n*** Running particle filter. ***\n');

% Initialise constants
Np = length(init_x_pts);
K = size(times, 2);
d = 3;

% Initialise arrays
x_pts_array = zeros(Np,K);
tau_pts_array = zeros(Np,K);
alpha_pts_array = zeros(Np,K);
last_x_pts = init_x_pts;
last_tau_pts = init_tau_pts;
last_alpha_pts = init_alpha_pts;

wts_array = zeros(Np,K);
last_wts = log(ones(Np,1)/Np);

% Loop through time
for kk = 1:K
    
    fprintf(1, 'Now processing frame %u.\n', kk);
    
    % Create a new particle array
    x_pts = zeros(Np,1);
    tau_pts = last_tau_pts;
    alpha_pts = last_alpha_pts;
    
    wts = last_wts;
    
    % Loop through particles
    for ii = 1:Np
        
        % Propose a new value for the particle
        [x_pts(ii,1), ~] = feval(h_trans, last_alpha_pts(ii,1), last_tau_pts(ii,1), last_x_pts(ii,1));
        
    end
    
    %%% Particle flow it to the posterior %%%
    
    % Find Gaussian mean and covariance of the predicted distribution
    pts = [x_pts, tau_pts, alpha_pts];    
    m = mean(pts)';
    P = cov(pts);
    
    H = [1 0 0]; R = params.obs_var;
    y = observs(1,kk);
    
    % Loop through particles
    for ii = 1:Np
        
        x = [x_pts(ii,1); tau_pts(ii,1); alpha_pts(ii,1)];
        
        dl = params.dl;
        for ll = 0:dl:1
            
            A = -0.5*P*H'*((R+ll*H*P*H')\H);
            b = (eye(d)+2*ll*A)*((eye(d)+ll*A)*P*H'*(R\y)+A*m);
            x = x + dl*(A*x+b);
            x(2) = max(x(2), 0.001);
            
        end
        
        x_pts(ii,1) = x(1);
        tau_pts(ii,1) = x(2);
        alpha_pts(ii,1) = x(3);
        
        [ y, obs_prb ] = feval(h_obs, R, x(1), y );
        wts(ii) = last_wts(ii) + log(obs_prb);
        
    end
    
    wts = normalise_weights(wts);
    [ parents ] = systematic_resample( wts, params.Nx );
    x_pts = x_pts(parents);
    tau_pts = tau_pts(parents);
    alpha_pts = alpha_pts(parents);
    wts = log(ones(Np,1)/Np);
    
    %%% End of particle flow bit %%%
    
    assert(all(~isinf(x_pts(:))));
    assert(all(~isnan(x_pts(:))));
    
    % Store particles and weights
    x_pts_array(:,kk) = x_pts;
    tau_pts_array(:,kk) = tau_pts;
    alpha_pts_array(:,kk) = alpha_pts;
    
    last_x_pts = x_pts;
    last_tau_pts = tau_pts;
    last_alpha_pts = alpha_pts;
    
    last_wts = wts;
    
end

end


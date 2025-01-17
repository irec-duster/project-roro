function  [t, state] = ascent_calc( roro,tend )
%Function calculates the ascent phase of the rocket
    global env
    global t_RailExit
    global v_RailExit
    global t_Burnout
   
    state_0 = [roro.X; roro.Q; roro.P; roro.L];
    tspan = [0,tend];
    
    % Event function to stop at max height
    options = odeset('Events',@event_function);
    
    % Solve flight using ODE45
    [t, state]= ode45(@flight,tspan,state_0,options);

    % --------------------------------------------------------------------------
    %% Equations of motion discribed to be sloved in ode45 
    function state_dot = flight(t,state)
        %TODO: put condition on burn data so it does not excecute after
        %bunout
        
        if (t>0)
            roro.deltat = t - roro.time;
            roro.time = t;
            burn_data(roro); % runs each cycle to update motor stats 
        end
        
        X= state(1:3);
        Q= state(4:7);
        P= state(8:10);
        L= state(11:13);

        roro.X= state(1:3); % Position in world COS
        roro.Q= state(4:7); % Orientation in world COS (quaternion)
        roro.P= state(8:10); % Forces
        roro.L= state(11:13); % Torques
        
        % Rotation matrix for transforming body coord to ground coord
        Rmatrix= quat2rotm(roro.Q');
        
        % Axis wrt earth coord
        YA = Rmatrix*env.YA0'; % Yaw axis
        PA = Rmatrix*env.PA0'; % Pitch axis
        RA = Rmatrix*env.RA0'; % Roll axis
        
        CnXcp = roro.CnXcp;
        Cn= CnXcp(1); % Normal force coeff
        Xcp= CnXcp(2); % Center of Pressure location
        Xcp_Barrow = CnXcp(3);
        Xcp_Planform = CnXcp(4);
        Cda = CnXcp(5); % Damping coefficient
        Cld = CnXcp(6);
        Zeta = CnXcp(7);
        CaCd = roro.CaCd;
        Ca = CaCd(1);
        Cd = CaCd(2);
        
        %% -------X Velocity-------
        Xdot=P./roro.Mass;
        %% -------Q Angular velocity--------- in quarternians 
        invIbody = roro.Ibody\eye(3); %inv(roro.Ibody); inverting matrix
        omega = Rmatrix*invIbody*Rmatrix'*L;
        s = Q(1);
        v =[Q(1); Q(2); Q(3)];
        sdot = -0.5*(dot(omega,v));
        vdot = 0.5*(s*omega + cross(omega,v));
        Qdot = [sdot; vdot];
        
        %% -------Angle of attack------- 
        % Angle between velocity vector of the CoP to the roll axis, given in the ground coord        
        % To Do : windmodel in env, Model gives errors 
        if(norm(X) < roro.Rail)
            W = [0, 0, 0]';
        else
            W = env.W;
        end
        
        Vcm = Xdot + W;
        
        omega_norm = normalize(omega); %normalized
        Xperp =(Xcp-roro.Xcm)*sin(acos(dot(RA,omega_norm))); % Perpendicular distance between omega and RA
        
        Vomega = Xperp *cross(RA,omega);
        
        V = Vcm + Vomega; % approxamating the velocity of the cop        
        
        Vmag = norm(V);
        Vnorm = normalize(V);
        alpha = acos(dot(Vnorm,RA));
        alpha = real(alpha);
        
        roro.alpha = alpha;
        
        %% -----P Liner Momentum-----

        Fthrust = roro.T*RA;
        
        mg = roro.Mass*env.g;
        Fg = [0, 0, -mg]';
        
        % Axial Forces
        Famag = 0.5*env.rho*Vmag^2*roro.A_ref*Ca; % Drag force
        
        Fa = -Famag*RA;
        
        % Normal Forces
        Fnmag = 0.5*env.rho*Vmag^2*roro.A_ref*Cn; % Lift force
        
        RA_Vplane = cross(RA,Vnorm);
        Fn = Fnmag*(cross(RA,RA_Vplane));
        
        if (roro.T< mg && X(3)< 0.1)
            Ftot = [0, 0, 0]';
        else
            Ftot = Fthrust + Fg + Fa + Fn;
        end
        
        %% -----L Angular Momentum------
        Trqn = Fnmag*(Xcp-roro.Xcm)*(RA_Vplane); 
        
        m=diag([1, 1, 0]);
        Trq_da = -Cda*Rmatrix*m*Rmatrix'*omega;
        %Tqm=(Cda1*omega)*omegaax2; rotational torque by motor
%        r_f = %TODO roll damping 
%         Trmag = 0.5*env.rho*Vmag^2*roro.A_ref*Cld;
%         Tr = Trmag*RA;
        if(norm(X) < roro.Rail)
            Trq = [0, 0, 0]';
        else
            Trq = Trqn+Trq_da;
        end
        
        %% -----Update rocket state derivatives-----
        roro.Xdot= Xdot;
        roro.Qdot= Qdot;
        roro.Pdot= Ftot;
        roro.Ldot= Trq;
        
        state_dot =[Xdot; Qdot; Ftot;Trq];
        %% -----Log Data for Plotting----
        SM_ExtendedBarrow = (Xcp-roro.Xcm)/roro.D; %Stability margin extended Barrowman eq (Body lift)
        SM_Barrow = (Xcp_Barrow-roro.Xcm)/roro.D; %Stability margin classic Barrowman eq
        
        logData(Xcp,Xcp_Barrow,roro.Xcm,SM_ExtendedBarrow,SM_Barrow,Zeta,Vmag,roro.Mass,alpha,Ca,t); % Eg roro.cd for drag norm(Xdot)/env.C     
        %% Launch rail exit Velocity
        if((X(3)-roro.Rail) <= 0.05 && (X(3)-roro.Rail) >= -0.05)
            v_RailExit = Vmag;
            t_RailExit = t;
        end
       
        %% Burnout time
        if(roro.propM_current<0.01 && t_Burnout==0)
            t_Burnout = t;
        end
    end
    
    function [value,isterminal,direction] = event_function(t,state)
    %% stops ode integration when the max height is reached 
        if (t > 1 && state(10) <= 0) % Linear momentum in z direction is zero
            value = 0; % when value = 0, an event is triggered
        else
            value =1;
        end
        isterminal = 1; % terminate after the first event
        direction = 0;  % get all the zeros
    end
end
 

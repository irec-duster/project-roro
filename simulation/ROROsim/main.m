%% Main 
clear all; clc;

% Global varialbes
global roro
global env
global log

% Create rocket class
roro = rocket(init_rocket());% creates class with the initial values
init_motor( roro ); %loads rocket motor

% Initilize Environmental variables 
%To Do: read to do doc

% optional argument: Elevation(m) Temperature(C)and Pressure(Pa)
env = environement(1400, 35, 85900 );



%% --- Figures Flight Info ---
% Phase: ascent
tend=30;
[t, state] = ascent_calc(roro,tend);

clog = clean_log(t);
h_max=max(state(:,3))

figure('Name','Flight 3D')
plot3(state(:,1),state(:,2),state(:,3))
xlabel('x(m)')
ylabel('y (m)')
zlabel('Height (m)')
title('Height 3D')
axis([-500 500 -500 500 0 3500])

figure('Name','Flight information');
subplot(2,1,1)
plot(t,state(:,3))
xlabel('Time(s)')
ylabel('Height (m)')
title('Height 1D')

subplot(2,1,2)
plot(clog(:,6),clog(:,5))
xlabel('Time')
ylabel('Xdot (m/s)')
title('Velocity')
axis([0 25 0 300])

%% --- Figures Stability ---
figure('Name','Stability Analysis')
subplot(4,1,1)
plot(clog(:,6),clog(:,1))
xlabel('Time')
ylabel('Xcp [m]')
title('Xcp')
axis([0 25 1 2])
% 
subplot(4,1,2)
plot(clog(:,6),clog(:,2))
xlabel('Time')
ylabel('Xcm [m]')
title('Xcg')
axis([0 25 1 2])
%
subplot(4,1,3)
plot(clog(:,6),clog(:,3))
xlabel('Time')
ylabel('Margin []')
title('Static Stability Margin')
axis([0 25 1 2])
%
subplot(4,1,4)
plot(clog(:,6),clog(:,4))
xlabel('Time')
ylabel('Zeta []')
title('Damping Ratio')
axis([0 25 0.05 0.15])

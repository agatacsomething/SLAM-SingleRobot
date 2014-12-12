num = '20';

%% Init of Map
global MAP; 
%global MAP2; 
MAP.res   = 0.1*1000; %meters

% MAP.xmin  = -10*1000;  %meters
% MAP.ymin  = -15*1000;
% MAP.xmax  =  25*1000;
% MAP.ymax  =  15*1000;

MAP.xmin  = -30*1000;  %meters
MAP.ymin  = -30*1000;
MAP.xmax  =  30*1000;
MAP.ymax  =  30*1000;

% dimensions of the map
MAP.sizex  = ceil((MAP.xmax - MAP.xmin) / MAP.res + 1); %cells
MAP.sizey  = ceil((MAP.ymax - MAP.ymin) / MAP.res + 1);

MAP.map = zeros(MAP.sizex,MAP.sizey,'int8');
MAP2.map = zeros(MAP.sizex,MAP.sizey,'int8');
log_prob= zeros(MAP.sizex,MAP.sizey);
log_odds= zeros(MAP.sizex,MAP.sizey);
% figure('name','Empty Map');
% imagesc(MAP.map);
%%

encoder_name = ['Encoders', num, '.mat']; 
imu_time = ['imuRaw', num '.mat']; 
load(imu_time);
load(encoder_name);
clear vals;

lidar_name = ['Hokuyo',num,'.mat'];
load(lidar_name);
lidar_times = Hokuyo0.ts; 
lidar_readings = Hokuyo0.ranges;

[lidar_val idx1] = getShift (lidar_times);
[gyro_val  idx2] = getShift(ts);
[encod_val idx3] = getShift(Encoders.ts);

lidar_start = idx1(1);
gyro_start= idx2(2);
encod_start= idx3(1);

%%
initEverything; 
lpd= length_per_degree;
rw= robot_width;
% x_robot_new_d(1)= 0;
% y_robot_new_d(1)= 0;
% thetas(1)=0;
th_enc= 0;
xencod(1)=0;
yencod(2)=0;
%%

lidar_readings= lidar_readings(:,lidar_start:end);

%[x_robot, y_robot, thetas] = workingGyroWithEncoder(num, gyro_start, encod_start);
%[x_robot, y_robot, timusamp] = getPose(encod_start, imu_new, encoder_counts, lpd, rw, 0, 0);
% x_robot_new = x_robot(1:end-1);
% y_robot_new = y_robot(1:end-1);

lidar_angles = Hokuyo0.angles; 
lidar_reading_new=lidar_readings;

anglespan = 150:950;
%totalpoints = length(anglespan*1863);
totalpoints = length(anglespan)*1863;
ocup_points= zeros(totalpoints, 2);

%lidar_angles = lidar_angles(150:950);
k=0;
m=0;

%%
[x_robot_new_d(1), y_robot_new_d(1), thetas_d(1), th_enc, ...
    	xencod(1), yencod(1)] = getPose(imu_new, encoder_counts,...
        lpd, rw, 0, 0, 0, 0, ...
        0, 0);
    
[ocup_points, log_prob, MAP] = getOccPoints2(anglespan, lidar_angles, ...
        lidar_reading_new, x_robot_new_d(1), y_robot_new_d(1),thetas_d(1),...
        log_prob, 1);
    
MAP2.map=MAP.map; 
log_odds= log_prob; 
%c = map_correlation(MAP.map,xis(:,1),yis(:,1),posY,x_range,y_range);
%surf(c)

%%
x_im = MAP.xmin:MAP.res:MAP.xmax; %x-positions of each pixel of the map
y_im = MAP.ymin:MAP.res:MAP.ymax; %y-positions of each pixel of the map

x_range = -1:0.05:1;
y_range = -1:0.05:1;
%%
%figure
tic
for i =1:1863
    
    [xpos_g(1), ypos_g(1), theta_g(1), th_enc, xencod(i+1), yencod(i+1)]=...
        getPose(imu_new, encoder_counts, lpd, rw, x_robot_new_d(i), ...
        y_robot_new_d(i), i, th_enc, xencod(i), yencod(i));
    
%     xpos_g(1) = x_robot_new_d(i+1);
%     ypos_g(1) = y_robot_new_d(i+1);
%     theta_g(1) = thetas_d(i+1);

    

    for n = 1:5
        [xpos_g(n+1), ypos_g(n+1), theta_g(n+1)] = ...
            getPossiblePose(xpos_g(1), ypos_g(1), theta_g(1), stdv);
    end
    
    for p = 1:length(xpos_g)
        k=0;
        xis= zeros(1081,1);
        yis= zeros(1081,1);
        x_robg = ceil((xpos_g(p) - MAP.xmin) ./ MAP.res);
        y_robg = ceil((ypos_g(p) - MAP.ymin) ./ MAP.res);
        
        for j = anglespan
                angle = (lidar_angles(j) +theta_g(p));
                lidar_reading=lidar_reading_new(j,2*i);
        
            if lidar_reading_new(j,2*i) > .1 && lidar_reading_new(j,2*i) < 5
                k=k+1;
                
                ocup_points(k,2*(p-1)+1) = (cos(angle)*(lidar_reading*1000))+xpos_g(p);
                ocup_points(k,2*(p-1)+2) = (sin(angle)*(lidar_reading*1000))+ypos_g(p);

                xis(k,1) = ceil((ocup_points(k,2*(p-1)+1) - MAP.xmin) ./ MAP.res);
                yis(k,1) = ceil((ocup_points(k,2*(p-1)+2) - MAP.ymin) ./ MAP.res);
                
                indGood = (xis(k,1) > 1) & (yis(k,1) > 1) & (xis(k,1) < MAP.sizex)...
                        & (yis(k,1) < MAP.sizey);
                
                if indGood ==1
                    inds = sub2ind(size(MAP.map),xis(k,1),yis(k,1));
                    if log_odds(inds)<30 && log_odds(inds)>-30
                        log_odds(inds) = log_odds(inds)+0.02; 
                    end
                
                

                
                    [ax, by] = getMapCellsFromRay(x_robg, y_robg, xis(k,1), yis(k,1));
                
                
                    for ii = 1: length(ax)
                        if log_odds(ax(ii),by(ii))>-30 && log_odds(ax(ii),by(ii))<30

                            log_odds(ax(ii),by(ii)) = log_odds(ax(ii),by(ii))- 0.01;
                        end
                    end
                end
              
            end
               
        end      
    
    
    %compute correlation

        posY = [ocup_points(:,2*(p-1)+1)'; ocup_points(:,2*(p-1)+2)'; zeros(1,length(ocup_points))];

         c(:,:,p) = map_correlation(int8(log_prob),x_im,y_im,posY,x_range,y_range);
       % c(:,:,p) = map_correlation(MAP.map,x_im,y_im,posY,x_range,y_range);
        
        maxes = max(max(c(:,:,p)));
        clear xis;
        clear yis; 
       % hold on; surf(c(:,:,p))
    end
    
   % [a,b] = mean(mean(c(:)));
    [p,o]= max(maxes); 
    
    x_robot_new_d(i+1) = xpos_g(o); 
    y_robot_new_d(i+1)= ypos_g(o); 
     
    ocup_points_d= [ocup_points(:,2*(o-1)+1), ocup_points(:,2*(o-1)+2)];
    
    x_rob = ceil((x_robot_new_d(i+1) - MAP.xmin) ./ MAP.res);
    y_rob = ceil((y_robot_new_d(i+1) - MAP.ymin) ./ MAP.res);
    
    if (abs(theta_g(o)-thetas_d(i))<0.005)
        thetas_d(i+1) = thetas_d(i);
    else
        thetas_d(i+1) = theta_g(o);
    end
        
    [log_prob, MAP] = updateMap2(log_prob, ocup_points_d, x_rob,y_rob);
    %here= mat2gray(log_prob);
    %hold on, imshow(here); hold on; 
%     

    plot_points(i,1)= x_rob;
    plot_points(i,2)= y_rob;
    log_odds= log_prob;
%    surf(c(:,:,o))
%     %plot(y_rob,x_rob,'r');
%    plot(plot_points(1:i,2), plot_points(1:i,1),'r');
%     popopop=1;
end

toc

%% check this out
% xis = ceil((ocup_points(:,1) - MAP.xmin) ./ MAP.res);
% yis = ceil((ocup_points(:,2) - MAP.ymin) ./ MAP.res);
%             
% %check the indices and populate the map
% % indGood = (xis > 1) & (yis > 1) & (xis < MAP.sizex) & (yis < MAP.sizey);
% % inds = sub2ind(size(MAP.map),xis(indGood),yis(indGood));
% % MAP.map(inds) = 100;
% 
% %compute correlation
% x_im = MAP.xmin:MAP.res:MAP.xmax; %x-positions of each pixel of the map
% y_im = MAP.ymin:MAP.res:MAP.ymax; %y-positions of each pixel of the map
% figure('name','Filled Map');
% imagesc(MAP.map);

%%


%compute correlation
x_im = MAP.xmin:MAP.res:MAP.xmax; %x-positions of each pixel of the map
y_im = MAP.ymin:MAP.res:MAP.ymax; %y-positions of each pixel of the map

x_range = -1:0.05:1;
y_range = -1:0.05:1;

posY = [x_robot_new_d;y_robot_new_d;zeros(size(y_robot_new_d))];

c = map_correlation(MAP.map,x_im,y_im,posY,x_range,y_range);

figure('name','Filled Map 2');
imagesc(MAP.map);

here= mat2gray(log_prob);
figure, imshow(here); %hold on; plot(-y_robot_new,x_robot_new,'r');
hold on; plot(plot_points(:,2), plot_points(:,1),'r');

figure(3);
surf(c)


load chirp
sound(y,Fs)

%%

%rgmyck
%bck
%figure;  %legend('encoder path', 'encoder with gryo path', 'Location', 'SouthEast')

%figure; plot(-ocup_points(76384:end,2),ocup_points(76384:end,1),'r.'); 
%hold on; plot(-y_robot_new,x_robot_new,'k');
% figure; plot(-ocup_points(:,2),ocup_points(:,1),'b.');
% hold on; plot(-y_robot_new_d,x_robot_new_d,'k');

%%
%                else
%                 m=m+1;
% 
%                 un_ocup_points(m,1) = (cos(angle)*(lidar_reading*1000))+xpos_g(p);
%                 un_ocup_points(m,2) = (sin(angle)*(lidar_reading*1000))+ypos_g(p);
% 
%                 xism(m,1) = ceil((un_ocup_points(m,1) - MAP.xmin) ./ MAP.res);
%                 yism(m,1) = ceil((un_ocup_points(m,2) - MAP.ymin) ./ MAP.res);
%                 indGood = (xism(m,1) > 1) & (yism(m,1) > 1) & (xism(m,1) < MAP.sizex)...
%                     & (yism(m,1) < MAP.sizey);
%                 if indGood ==1
%                     inds = sub2ind(size(MAP.map),xism(m,1),yism(m,1));
%                     log_prob(inds) = log_prob(inds)+0.05; 
%                     MAP.map(inds) = MAP.map(inds)+0.02;
%                 end


                 % continue
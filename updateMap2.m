function [log_prob, MAP] = updateMap2(log_prob, ocup_points,x_rob,y_rob)
%k=0;
global MAP; 

for k = 1:length(ocup_points)
%k=k+1;
        
        xis(k,1) = ceil((ocup_points(k,1) - MAP.xmin) ./ MAP.res);
        yis(k,1) = ceil((ocup_points(k,2) - MAP.ymin) ./ MAP.res);
                
        indGood = (xis(k,1) > 1) & (yis(k,1) > 1) & (xis(k,1) < MAP.sizex)...
                & (yis(k,1) < MAP.sizey);
    
            
        if indGood ==1
            inds = sub2ind(size(MAP.map),xis(k,1),yis(k,1));
            if log_prob(inds)<30
                log_prob(inds) = log_prob(inds)+0.02; 
            end
            
            MAP.map(inds) = MAP.map(inds)+1;
        end 

        [ax, by] = getMapCellsFromRay(x_rob, y_rob, xis(k,1), yis(k,1));
                
                
        for ii = 1: length(ax)
        	if log_prob(ax(ii),by(ii))>-30 && log_prob(ax(ii),by(ii))<30

            	log_prob(ax(ii),by(ii)) = log_prob(ax(ii),by(ii))- 0.01;
            end
        end
               
        clear ax;
        clear by; 
end
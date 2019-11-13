function F = root2d(x,y,z)
F = [(x(1)*(gamma(1+(1/x(2)))))-y;...
     (x(1)*(sqrt((gamma(1+(2/x(2))))-((gamma(1+(1/x(2))))^2))))-z];


%%%%%%%%%% MATERIAL FLOW ANALYSIS MODEL -CONSUMER ELECTRONICS

%% READ DATA

%Product Table - specify input as a CSV format
prod_sheet = readtable('Product_Details_Input.csv');


%Bill of Materials
Material_sheet = readtable('Product_Material_Composition_Input.csv');

%Sub component sheet
Subcomponent_sheet = readtable('Component_Material_Composition_Input.csv');

%Sales Mass
prod_sheet.Sales_mass = ((prod_sheet.Sales_units).*(prod_sheet.AverageProductMass_kg));

%prod_list
prod_list = unique(prod_sheet.ProductID);

%% START MATERIAL FLOW PROCESS -SALES LIFESPAN METHOD

%% MATERIAL FLOW PRODUCT LEVEL

%% MFA TO ESTIMATE ANNUAL PRODUCT WASTE FLOW IN UNITS

COL_YR = [min(prod_sheet.Year):1:max(prod_sheet.Year)]';
COL_TOP_DOWN_OUTFLOW = [];
x=[];

for i=prod_list'
    
   rows = (prod_sheet.ProductID==i);
        vars = {'Maximum_Lifespan'};
        Max_Lifespan = min(prod_sheet{rows,vars}); 
        Mean_Lifespan= min (prod_sheet{rows,'Mean_Lifespan'}); 
       Std_dev_Lifespan= min (prod_sheet{rows,'Std_dev_Lifespan'});
X =  1:Max_Lifespan;%X is min to max L
%generate probability of lifespan
x0 = [1 1];

options = optimset('Display','iter');
x= fsolve(@(x0) root2d(x0,Mean_Lifespan,Std_dev_Lifespan),x0,options);

%x= fsolve(@root2d,x0,options);

P = cdf('Weibull',X,x(1),x(2));%x(1) is scale parameter,%x(2)is shape parameter
Pp= pdf('Weibull',X,x(1),x(2));
% P = cdf('Lognormal',X,x(1),x(2));       
        start_yr = min(prod_sheet(prod_sheet.ProductID==i,:).Year);
        end_yr = max(prod_sheet(prod_sheet.ProductID==i,:).Year);
        add_this_yr_topdownOF=[];
        
        for Y_OFU=start_yr+1:1:end_yr
             topdown_outflow_withP =0;
         for m = 1:length(P)
        Yr_N_OFU= Y_OFU-X(m);
        rows = (prod_sheet.ProductID==i&prod_sheet.Year==Yr_N_OFU);
        vars = {'Sales_units'};
        topdown_outflow_sales = prod_sheet{rows,vars};
        if isempty(topdown_outflow_sales)
          topdown_outflow_sales =0;
        end
        
        if m==1
        topdown_outflow_withP = topdown_outflow_withP+topdown_outflow_sales*(P(m));
        else
            topdown_outflow_withP = topdown_outflow_withP+(topdown_outflow_sales*(P(m)-P(m-1)));
        end
         end
        add_this_yr_topdownOF = [add_this_yr_topdownOF;topdown_outflow_withP,i,Y_OFU];
        end
    COL_TOP_DOWN_OUTFLOW  = [COL_TOP_DOWN_OUTFLOW ;add_this_yr_topdownOF];

end

%% MFA TO ESTIMATE ANNUAL PRODUCT WASTE FLOW IN MASS (KG)


COL_YR = [min(prod_sheet.Year):1:max(prod_sheet.Year)]';
COL_TOP_DOWN_OUTFLOW_MASS = [];
x=[];

for i=prod_list'
    
   rows = (prod_sheet.ProductID==i);
        vars = {'Maximum_Lifespan'};
        Max_Lifespan = min(prod_sheet{rows,vars}); 
        Mean_Lifespan= min (prod_sheet{rows,'Mean_Lifespan'}); 
       Std_dev_Lifespan= min (prod_sheet{rows,'Std_dev_Lifespan'});
X =  1:Max_Lifespan;%X is min to max L
%generate probability of lifespan
x0 = [1 1];

options = optimset('Display','iter');
x= fsolve(@(x0) root2d(x0,Mean_Lifespan,Std_dev_Lifespan),x0,options);

%x= fsolve(@root2d,x0,options);

P = cdf('Weibull',X,x(1),x(2));%x(1) is scale parameter,%x(2)is shape parameter
% P = cdf('Lognormal',X,x(1),x(2));       
        start_yr = min(prod_sheet(prod_sheet.ProductID==i,:).Year);
        end_yr = max(prod_sheet(prod_sheet.ProductID==i,:).Year);
        add_this_yr_topdownOFMASS=[];
        
        for Y_OFM=start_yr+1:1:end_yr
             topdown_outflowmass_withP =0;
         for m = 1:length(P)
        Yr_N= Y_OFM-X(m);
        rows = (prod_sheet.ProductID==i&prod_sheet.Year==Yr_N);
        vars1 = {'Sales_mass'};
        topdown_outflow_salesmass = prod_sheet{rows,vars1};
        if isempty(topdown_outflow_salesmass)
          topdown_outflow_salesmass =0;
        end
        if m==1
        topdown_outflowmass_withP = topdown_outflowmass_withP+topdown_outflow_salesmass*(P(m));
        else
            topdown_outflowmass_withP = topdown_outflowmass_withP+(topdown_outflow_salesmass*(P(m)-P(m-1)));
        end
         end
        add_this_yr_topdownOFMASS = [add_this_yr_topdownOFMASS;topdown_outflowmass_withP,i,Y_OFM];
        end
    COL_TOP_DOWN_OUTFLOW_MASS  = [COL_TOP_DOWN_OUTFLOW_MASS ;add_this_yr_topdownOFMASS];
end

%Converting array to table with headers
TopDown_Outflow_sheet = table(COL_TOP_DOWN_OUTFLOW(:,1), COL_TOP_DOWN_OUTFLOW_MASS(:,1),COL_TOP_DOWN_OUTFLOW(:,2),COL_TOP_DOWN_OUTFLOW(:,3),...
   'VariableNames',{'Productwasteflow_units' 'Productwasteflow_mass_kg' 'ProductID' 'Year'});



%Join the table with stock and sales with the table with top down outflow 
Inflow_sheet_T_all = outerjoin(prod_sheet,TopDown_Outflow_sheet);

%Remove recurring columns in the table
Inflow_sheet_T_all(:,end-1:end)=[];


%Changing variable names
Inflow_sheet_T_all.Properties.VariableNames{'Year_prod_sheet'}='Year';

Inflow_sheet_T = Inflow_sheet_T_all(Inflow_sheet_T_all.Year > 1989,:);
Inflow_sheet_T .Properties.VariableNames{'ProductID_prod_sheet'}='ProductID';
writetable(Inflow_sheet_T,'MFAOUTPUT Product flows.xls');

%% MFA TO ESTIMATE HIGH LEVEL MATERIAL FLOWS (BASE METALS, PLASTICS AND COMPONENTS)
%Apply Product Material Composition 
%% MATERIAL INFLOWS 

%Merge sheets
New_allsheet = outerjoin(prod_sheet,Material_sheet);
New_allsheet.Properties.VariableNames{'Year_prod_sheet'}='Year';

%Variables for Materials
New_allsheet.Fe_Incomingmass = ((New_allsheet.Sales_mass).*(New_allsheet.Fe));
New_allsheet.Al_Incomingmass = ((New_allsheet.Sales_mass).*(New_allsheet.Al));
New_allsheet.Cu_Incomingmass = ((New_allsheet.Sales_mass).*(New_allsheet.Cu));
New_allsheet.Plastics_Incomingmass = ((New_allsheet.Sales_mass).*(New_allsheet.Plastics));
New_allsheet.Other_metals_Incomingmass = ((New_allsheet.Sales_mass).*(New_allsheet.Other_metals));
New_allsheet.Others_Incomingmass= ((New_allsheet.Sales_mass).*(New_allsheet.Others));

New_allsheet.PCB_Incomingmass = ((New_allsheet.Sales_mass).*(New_allsheet.PCB));
New_allsheet.CRTGlass_incomingmass = ((New_allsheet.Sales_mass).*(New_allsheet.CRT_Glass));

New_allsheet.LIB_incomingmass = ((New_allsheet.Sales_mass).*(New_allsheet.Li_battery));

New_allsheet.LCD_module_CCFL_incomingmass = ((New_allsheet.Sales_mass).*(New_allsheet.LCD_module_CCFL));
New_allsheet.LCD_module_LED_incomingmass = ((New_allsheet.Sales_mass).*(New_allsheet.LCD_module_LED));


%% MATERIAL WASTEFLOWS

%% Fe wasteflow from each product

COL_YR = [min(New_allsheet.Year):1:max(New_allsheet.Year)]';
COL_TOP_DOWN_FeOUTFLOW_MASS = [];
x=[];

for i=prod_list'
    
   rows = (New_allsheet.ProductID_prod_sheet==i);
        vars = {'Maximum_Lifespan'};
        Max_Lifespan = min(New_allsheet{rows,vars}); 
        Mean_Lifespan= min (New_allsheet{rows,'Mean_Lifespan'}); 
       Std_dev_Lifespan= min (New_allsheet{rows,'Std_dev_Lifespan'});
XXX_f =  1:Max_Lifespan;%X is min to max L
%generate probability of lifespan
x0 = [1 1];

options = optimset('Display','iter');
x= fsolve(@(x0) root2d(x0,Mean_Lifespan,Std_dev_Lifespan),x0,options);


P_f = cdf('Weibull',XXX_f,x(1),x(2));%x(1) is scale parameter,%x(2)is shape parameter
       
        start_yr = min(New_allsheet(New_allsheet.ProductID_prod_sheet==i,:).Year);
        end_yr = max(New_allsheet(New_allsheet.ProductID_prod_sheet==i,:).Year);
        add_this_yr_FeOFMASS=[];
        
        for Y=start_yr+1:1:end_yr
             topdown_Feoutflowmass_withP =0;
         for m = 1:length(P_f)
        Yr_N= Y-XXX_f(m);
        rows = (New_allsheet.ProductID_prod_sheet==i&New_allsheet.Year==Yr_N);
        vars_f = {'Fe_Incomingmass'};
        topdown_outflow_Feoutflowmass = New_allsheet{rows,vars_f};
        if isempty(topdown_outflow_Feoutflowmass)
          topdown_outflow_Feoutflowmass =0;
        end
        if m==1
        topdown_Feoutflowmass_withP = topdown_Feoutflowmass_withP+topdown_outflow_Feoutflowmass*(P_f(m));
        else
            topdown_Feoutflowmass_withP = topdown_Feoutflowmass_withP+(topdown_outflow_Feoutflowmass*(P_f(m)-P_f(m-1)));
        end
         end
        add_this_yr_FeOFMASS = [add_this_yr_FeOFMASS;topdown_Feoutflowmass_withP,i,Y];
        end
    COL_TOP_DOWN_FeOUTFLOW_MASS  = [COL_TOP_DOWN_FeOUTFLOW_MASS ;add_this_yr_FeOFMASS];
end

%% Al wasteflow from each product

COL_YR = [min(New_allsheet.Year):1:max(New_allsheet.Year)]';
COL_TOP_DOWN_AlOUTFLOW_MASS = [];
x=[];

for i=prod_list'
    
   rows = (New_allsheet.ProductID_prod_sheet==i);
        vars = {'Maximum_Lifespan'};
        Max_Lifespan = min(New_allsheet{rows,vars}); 
        Mean_Lifespan= min (New_allsheet{rows,'Mean_Lifespan'}); 
       Std_dev_Lifespan= min (New_allsheet{rows,'Std_dev_Lifespan'});
XXX_a =  1:Max_Lifespan;%X is min to max L
%generate probability of lifespan
x0 = [1 1];

options = optimset('Display','iter');
x= fsolve(@(x0) root2d(x0,Mean_Lifespan,Std_dev_Lifespan),x0,options);


P_a = cdf('Weibull',XXX_a,x(1),x(2));%x(1) is scale parameter,%x(2)is shape parameter
       
        start_yr = min(New_allsheet(New_allsheet.ProductID_prod_sheet==i,:).Year);
        end_yr = max(New_allsheet(New_allsheet.ProductID_prod_sheet==i,:).Year);
        add_this_yr_AlOFMASS=[];
        
        for Y=start_yr+1:1:end_yr
             topdown_Aloutflowmass_withP =0;
         for m = 1:length(P_a)
        Yr_N= Y-XXX_a(m);
        rows = (New_allsheet.ProductID_prod_sheet==i&New_allsheet.Year==Yr_N);
        vars_a = {'Al_Incomingmass'};
        topdown_outflow_Aloutflowmass = New_allsheet{rows,vars_a};
        if isempty(topdown_outflow_Aloutflowmass)
          topdown_outflow_Aloutflowmass =0;
        end
        if m==1
        topdown_Aloutflowmass_withP = topdown_Aloutflowmass_withP+topdown_outflow_Aloutflowmass*(P_a(m));
        else
            topdown_Aloutflowmass_withP = topdown_Aloutflowmass_withP+(topdown_outflow_Aloutflowmass*(P_a(m)-P_a(m-1)));
        end
         end
        add_this_yr_AlOFMASS = [add_this_yr_AlOFMASS;topdown_Aloutflowmass_withP,i,Y];
        end
    COL_TOP_DOWN_AlOUTFLOW_MASS  = [COL_TOP_DOWN_AlOUTFLOW_MASS ;add_this_yr_AlOFMASS];
end

%% Cu wasteflow from each product


COL_YR = [min(New_allsheet.Year):1:max(New_allsheet.Year)]';
COL_TOP_DOWN_CuOUTFLOW_MASS = [];
x=[];

for i=prod_list'
    
   rows = (New_allsheet.ProductID_prod_sheet==i);
        vars = {'Maximum_Lifespan'};
        Max_Lifespan = min(New_allsheet{rows,vars}); 
        Mean_Lifespan= min (New_allsheet{rows,'Mean_Lifespan'}); 
       Std_dev_Lifespan= min (New_allsheet{rows,'Std_dev_Lifespan'});
XXX_cu =  1:Max_Lifespan;%X is min to max L
%generate probability of lifespan
x0 = [1 1];

options = optimset('Display','iter');
x= fsolve(@(x0) root2d(x0,Mean_Lifespan,Std_dev_Lifespan),x0,options);


P_cu = cdf('Weibull',XXX_cu,x(1),x(2));%x(1) is scale parameter,%x(2)is shape parameter
       
        start_yr = min(New_allsheet(New_allsheet.ProductID_prod_sheet==i,:).Year);
        end_yr = max(New_allsheet(New_allsheet.ProductID_prod_sheet==i,:).Year);
        add_this_yr_CuOFMASS=[];
        
        for Y=start_yr+1:1:end_yr
             topdown_Cuoutflowmass_withP =0;
         for m = 1:length(P_cu)
        Yr_N= Y-XXX_cu(m);
        rows = (New_allsheet.ProductID_prod_sheet==i&New_allsheet.Year==Yr_N);
        vars_cu = {'Cu_Incomingmass'};
        topdown_outflow_Cuoutflowmass = New_allsheet{rows,vars_cu};
        if isempty(topdown_outflow_Cuoutflowmass)
          topdown_outflow_Cuoutflowmass =0;
        end
        if m==1
        topdown_Cuoutflowmass_withP = topdown_Cuoutflowmass_withP+topdown_outflow_Cuoutflowmass*(P_cu(m));
        else
            topdown_Cuoutflowmass_withP = topdown_Cuoutflowmass_withP+(topdown_outflow_Cuoutflowmass*(P_cu(m)-P_cu(m-1)));
        end
         end
        add_this_yr_CuOFMASS = [add_this_yr_CuOFMASS;topdown_Cuoutflowmass_withP,i,Y];
        end
    COL_TOP_DOWN_CuOUTFLOW_MASS  = [COL_TOP_DOWN_CuOUTFLOW_MASS ;add_this_yr_CuOFMASS];
end

%% Plastics wasteflow from each product


COL_YR = [min(New_allsheet.Year):1:max(New_allsheet.Year)]';
COL_TOP_DOWN_PlasticsOUTFLOW_MASS = [];
x=[];

for i=prod_list'
    
   rows = (New_allsheet.ProductID_prod_sheet==i);
        vars = {'Maximum_Lifespan'};
        Max_Lifespan = min(New_allsheet{rows,vars}); 
        Mean_Lifespan= min (New_allsheet{rows,'Mean_Lifespan'}); 
       Std_dev_Lifespan= min (New_allsheet{rows,'Std_dev_Lifespan'});
XXX_pl =  1:Max_Lifespan;%X is min to max L
%generate probability of lifespan
x0 = [1 1];

options = optimset('Display','iter');
x= fsolve(@(x0) root2d(x0,Mean_Lifespan,Std_dev_Lifespan),x0,options);


P_pl = cdf('Weibull',XXX_pl,x(1),x(2));%x(1) is scale parameter,%x(2)is shape parameter
       
        start_yr = min(New_allsheet(New_allsheet.ProductID_prod_sheet==i,:).Year);
        end_yr = max(New_allsheet(New_allsheet.ProductID_prod_sheet==i,:).Year);
        add_this_yr_PlasticsOFMASS=[];
        
        for Y=start_yr+1:1:end_yr
             topdown_Plasticsoutflowmass_withP =0;
         for m = 1:length(P_pl)
        Yr_N= Y-XXX_pl(m);
        rows = (New_allsheet.ProductID_prod_sheet==i&New_allsheet.Year==Yr_N);
        vars_pl = {'Plastics_Incomingmass'};
        topdown_outflow_Plasticsoutflowmass = New_allsheet{rows,vars_pl};
        if isempty(topdown_outflow_Plasticsoutflowmass)
          topdown_outflow_Plasticsoutflowmass =0;
        end
        if m==1
        topdown_Plasticsoutflowmass_withP = topdown_Plasticsoutflowmass_withP+topdown_outflow_Plasticsoutflowmass*(P_pl(m));
        else
            topdown_Plasticsoutflowmass_withP = topdown_Plasticsoutflowmass_withP+(topdown_outflow_Plasticsoutflowmass*(P_pl(m)-P_pl(m-1)));
        end
         end
        add_this_yr_PlasticsOFMASS = [add_this_yr_PlasticsOFMASS;topdown_Plasticsoutflowmass_withP,i,Y];
        end
    COL_TOP_DOWN_PlasticsOUTFLOW_MASS  = [COL_TOP_DOWN_PlasticsOUTFLOW_MASS ;add_this_yr_PlasticsOFMASS];
end

%% Other metals wasteflow from each product


COL_YR = [min(New_allsheet.Year):1:max(New_allsheet.Year)]';
COL_TOP_DOWN_OmOUTFLOW_MASS = [];
x=[];

for i=prod_list'
    
   rows = (New_allsheet.ProductID_prod_sheet==i);
        vars = {'Maximum_Lifespan'};
        Max_Lifespan = min(New_allsheet{rows,vars}); 
        Mean_Lifespan= min (New_allsheet{rows,'Mean_Lifespan'}); 
       Std_dev_Lifespan= min (New_allsheet{rows,'Std_dev_Lifespan'});
XXX_om =  1:Max_Lifespan;%X is min to max L
%generate probability of lifespan
x0 = [1 1];

options = optimset('Display','iter');
x= fsolve(@(x0) root2d(x0,Mean_Lifespan,Std_dev_Lifespan),x0,options);


P_om = cdf('Weibull',XXX_om,x(1),x(2));%x(1) is scale parameter,%x(2)is shape parameter
       
        start_yr = min(New_allsheet(New_allsheet.ProductID_prod_sheet==i,:).Year);
        end_yr = max(New_allsheet(New_allsheet.ProductID_prod_sheet==i,:).Year);
        add_this_yr_OmOFMASS=[];
        
        for Y=start_yr+1:1:end_yr
             topdown_Omoutflowmass_withP =0;
         for m = 1:length(P_om)
        Yr_N= Y-XXX_om(m);
        rows = (New_allsheet.ProductID_prod_sheet==i&New_allsheet.Year==Yr_N);
        vars_om = {'Other_metals_Incomingmass'};
        topdown_outflow_Omoutflowmass = New_allsheet{rows,vars_om};
        if isempty(topdown_outflow_Omoutflowmass)
          topdown_outflow_Omoutflowmass =0;
        end
        if m==1
        topdown_Omoutflowmass_withP = topdown_Omoutflowmass_withP+topdown_outflow_Omoutflowmass*(P_om(m));
        else
            topdown_Omoutflowmass_withP = topdown_Omoutflowmass_withP+(topdown_outflow_Omoutflowmass*(P_om(m)-P_om(m-1)));
        end
         end
        add_this_yr_OmOFMASS = [add_this_yr_OmOFMASS;topdown_Omoutflowmass_withP,i,Y];
        end
    COL_TOP_DOWN_OmOUTFLOW_MASS  = [COL_TOP_DOWN_OmOUTFLOW_MASS ;add_this_yr_OmOFMASS];
end

%% Others wasteflow from each product


COL_YR = [min(New_allsheet.Year):1:max(New_allsheet.Year)]';
COL_TOP_DOWN_OtOUTFLOW_MASS = [];
x=[];

for i=prod_list'
    
   rows = (New_allsheet.ProductID_prod_sheet==i);
        vars = {'Maximum_Lifespan'};
        Max_Lifespan = min(New_allsheet{rows,vars}); 
        Mean_Lifespan= min (New_allsheet{rows,'Mean_Lifespan'}); 
       Std_dev_Lifespan= min (New_allsheet{rows,'Std_dev_Lifespan'});
XXX_ot =  1:Max_Lifespan;%X is min to max L
%generate probability of lifespan
x0 = [1 1];

options = optimset('Display','iter');
x= fsolve(@(x0) root2d(x0,Mean_Lifespan,Std_dev_Lifespan),x0,options);


P_ot = cdf('Weibull',XXX_ot,x(1),x(2));%x(1) is scale parameter,%x(2)is shape parameter
       
        start_yr = min(New_allsheet(New_allsheet.ProductID_prod_sheet==i,:).Year);
        end_yr = max(New_allsheet(New_allsheet.ProductID_prod_sheet==i,:).Year);
        add_this_yr_OtOFMASS=[];
        
        for Y=start_yr+1:1:end_yr
             topdown_Otoutflowmass_withP =0;
         for m = 1:length(P_ot)
        Yr_N= Y-XXX_ot(m);
        rows = (New_allsheet.ProductID_prod_sheet==i&New_allsheet.Year==Yr_N);
        vars_ot = {'Others_Incomingmass'};
        topdown_outflow_Otoutflowmass = New_allsheet{rows,vars_ot};
        if isempty(topdown_outflow_Otoutflowmass)
          topdown_outflow_Otoutflowmass =0;
        end
        if m==1
        topdown_Otoutflowmass_withP = topdown_Otoutflowmass_withP+topdown_outflow_Otoutflowmass*(P_ot(m));
        else
            topdown_Otoutflowmass_withP = topdown_Otoutflowmass_withP+(topdown_outflow_Otoutflowmass*(P_ot(m)-P_ot(m-1)));
        end
         end
        add_this_yr_OtOFMASS = [add_this_yr_OtOFMASS;topdown_Otoutflowmass_withP,i,Y];
        end
    COL_TOP_DOWN_OtOUTFLOW_MASS  = [COL_TOP_DOWN_OtOUTFLOW_MASS ;add_this_yr_OtOFMASS];
end

%% PCB (Printed Circuit Board) wasteflow from each product

COL_YR = [min(New_allsheet.Year):1:max(New_allsheet.Year)]';
COL_TOP_DOWN_PCBOUTFLOW_MASS = [];
x=[];

for i=prod_list'
    
   rows = (New_allsheet.ProductID_prod_sheet==i);
        vars = {'Maximum_Lifespan'};
        Max_Lifespan = min(New_allsheet{rows,vars}); 
        Mean_Lifespan= min (New_allsheet{rows,'Mean_Lifespan'}); 
       Std_dev_Lifespan= min (New_allsheet{rows,'Std_dev_Lifespan'});
XXX_pcb =  1:Max_Lifespan;%X is min to max L
%generate probability of lifespan
x0 = [1 1];

options = optimset('Display','iter');
x= fsolve(@(x0) root2d(x0,Mean_Lifespan,Std_dev_Lifespan),x0,options);


P_pcb = cdf('Weibull',XXX_pcb,x(1),x(2));%x(1) is scale parameter,%x(2)is shape parameter
       
        start_yr = min(New_allsheet(New_allsheet.ProductID_prod_sheet==i,:).Year);
        end_yr = max(New_allsheet(New_allsheet.ProductID_prod_sheet==i,:).Year);
        add_this_yr_PCBOFMASS=[];
        
        for Y=start_yr+1:1:end_yr
             topdown_pcboutflowmass_withP =0;
         for m = 1:length(P_pcb)
        Yr_N= Y-XXX_pcb(m);
        rows = (New_allsheet.ProductID_prod_sheet==i&New_allsheet.Year==Yr_N);
        vars_pcb = {'PCB_Incomingmass'};
        topdown_outflow_pcboutflowmass = New_allsheet{rows,vars_pcb};
        if isempty(topdown_outflow_pcboutflowmass)
          topdown_outflow_pcboutflowmass =0;
        end
        if m==1
        topdown_pcboutflowmass_withP = topdown_pcboutflowmass_withP+topdown_outflow_pcboutflowmass*(P_pcb(m));
        else
            topdown_pcboutflowmass_withP = topdown_pcboutflowmass_withP+(topdown_outflow_pcboutflowmass*(P_pcb(m)-P_pcb(m-1)));
        end
         end
        add_this_yr_PCBOFMASS = [add_this_yr_PCBOFMASS;topdown_pcboutflowmass_withP,i,Y];
        end
    COL_TOP_DOWN_PCBOUTFLOW_MASS  = [COL_TOP_DOWN_PCBOUTFLOW_MASS ;add_this_yr_PCBOFMASS];
end

%% CRT Glass  wasteflow from each product

COL_YR = [min(New_allsheet.Year):1:max(New_allsheet.Year)]';
COL_TOP_DOWN_CRTOUTFLOW_MASS = [];
x=[];

for i=prod_list'
    
   rows = (New_allsheet.ProductID_prod_sheet==i);
        vars = {'Maximum_Lifespan'};
        Max_Lifespan = min(New_allsheet{rows,vars}); 
        Mean_Lifespan= min (New_allsheet{rows,'Mean_Lifespan'}); 
       Std_dev_Lifespan= min (New_allsheet{rows,'Std_dev_Lifespan'});
XXX_crt =  1:Max_Lifespan;%X is min to max L
%generate probability of lifespan
x0 = [1 1];

options = optimset('Display','iter');
x= fsolve(@(x0) root2d(x0,Mean_Lifespan,Std_dev_Lifespan),x0,options);


P_crt = cdf('Weibull',XXX_crt,x(1),x(2));%x(1) is scale parameter,%x(2)is shape parameter
       
        start_yr = min(New_allsheet(New_allsheet.ProductID_prod_sheet==i,:).Year);
        end_yr = max(New_allsheet(New_allsheet.ProductID_prod_sheet==i,:).Year);
        add_this_yr_CRTOFMASS=[];
        
        for Y=start_yr+1:1:end_yr
             topdown_crtoutflowmass_withP =0;
         for m = 1:length(P_crt)
        Yr_N= Y-XXX_crt(m);
        rows = (New_allsheet.ProductID_prod_sheet==i&New_allsheet.Year==Yr_N);
        vars_crt= {'CRTGlass_incomingmass'};
        topdown_outflow_crtoutflowmass = New_allsheet{rows,vars_crt};
        if isempty(topdown_outflow_crtoutflowmass)
          topdown_outflow_crtoutflowmass =0;
        end
        if m==1
        topdown_crtoutflowmass_withP = topdown_crtoutflowmass_withP+topdown_outflow_crtoutflowmass*(P_crt(m));
        else
            topdown_crtoutflowmass_withP = topdown_crtoutflowmass_withP+(topdown_outflow_crtoutflowmass*(P_crt(m)-P_crt(m-1)));
        end
         end
        add_this_yr_CRTOFMASS = [add_this_yr_CRTOFMASS;topdown_crtoutflowmass_withP,i,Y];
        end
    COL_TOP_DOWN_CRTOUTFLOW_MASS  = [COL_TOP_DOWN_CRTOUTFLOW_MASS ;add_this_yr_CRTOFMASS];
end

%% Battery wasteflow from each product

COL_YR = [min(New_allsheet.Year):1:max(New_allsheet.Year)]';
COL_TOP_DOWN_LIBOUTFLOW_MASS = [];
x=[];

for i=prod_list'
    
   rows = (New_allsheet.ProductID_prod_sheet==i);
        vars = {'Maximum_Lifespan'};
        Max_Lifespan = min(New_allsheet{rows,vars}); 
        Mean_Lifespan= min (New_allsheet{rows,'Mean_Lifespan'}); 
       Std_dev_Lifespan= min (New_allsheet{rows,'Std_dev_Lifespan'});
XXX_lib =  1:Max_Lifespan;%X is min to max L
%generate probability of lifespan
x0 = [1 1];

options = optimset('Display','iter');
x= fsolve(@(x0) root2d(x0,Mean_Lifespan,Std_dev_Lifespan),x0,options);


P_lib = cdf('Weibull',XXX_lib,x(1),x(2));%x(1) is scale parameter,%x(2)is shape parameter
       
        start_yr = min(New_allsheet(New_allsheet.ProductID_prod_sheet==i,:).Year);
        end_yr = max(New_allsheet(New_allsheet.ProductID_prod_sheet==i,:).Year);
        add_this_yr_LIBOFMASS=[];
        
        for Y=start_yr+1:1:end_yr
             topdown_liboutflowmass_withP =0;
         for m = 1:length(P_lib)
        Yr_N= Y-XXX_lib(m);
        rows = (New_allsheet.ProductID_prod_sheet==i&New_allsheet.Year==Yr_N);
        vars_lib= {'LIB_incomingmass'};
        topdown_outflow_liboutflowmass = New_allsheet{rows,vars_lib};
        if isempty(topdown_outflow_liboutflowmass)
          topdown_outflow_liboutflowmass =0;
        end
        if m==1
        topdown_liboutflowmass_withP = topdown_liboutflowmass_withP+topdown_outflow_liboutflowmass*(P_lib(m));
        else
            topdown_liboutflowmass_withP = topdown_liboutflowmass_withP+(topdown_outflow_liboutflowmass*(P_lib(m)-P_lib(m-1)));
        end
         end
        add_this_yr_LIBOFMASS = [add_this_yr_LIBOFMASS;topdown_liboutflowmass_withP,i,Y];
        end
    COL_TOP_DOWN_LIBOUTFLOW_MASS  = [COL_TOP_DOWN_LIBOUTFLOW_MASS ;add_this_yr_LIBOFMASS];
end

%% LCD Display wasteflow from each product

COL_YR = [min(New_allsheet.Year):1:max(New_allsheet.Year)]';
COL_TOP_DOWN_LCCFLOUTFLOW_MASS = [];
x=[];

for i=prod_list'
    
   rows = (New_allsheet.ProductID_prod_sheet==i);
        vars = {'Maximum_Lifespan'};
        Max_Lifespan = min(New_allsheet{rows,vars}); 
        Mean_Lifespan= min (New_allsheet{rows,'Mean_Lifespan'}); 
       Std_dev_Lifespan= min (New_allsheet{rows,'Std_dev_Lifespan'});
XXX_lccfl =  1:Max_Lifespan;%X is min to max L
%generate probability of lifespan
x0 = [1 1];

options = optimset('Display','iter');
x= fsolve(@(x0) root2d(x0,Mean_Lifespan,Std_dev_Lifespan),x0,options);


P_lccfl = cdf('Weibull',XXX_lccfl,x(1),x(2));%x(1) is scale parameter,%x(2)is shape parameter
       
        start_yr = min(New_allsheet(New_allsheet.ProductID_prod_sheet==i,:).Year);
        end_yr = max(New_allsheet(New_allsheet.ProductID_prod_sheet==i,:).Year);
        add_this_yr_LCCFLOFMASS=[];
        
        for Y=start_yr+1:1:end_yr
             topdown_lccfloutflowmass_withP =0;
         for m = 1:length(P_lccfl)
        Yr_N= Y-XXX_lccfl(m);
        rows = (New_allsheet.ProductID_prod_sheet==i&New_allsheet.Year==Yr_N);
        vars_lccfl= {'LCD_module_CCFL_incomingmass'};
        topdown_outflow_lccfloutflowmass = New_allsheet{rows,vars_lccfl};
        if isempty(topdown_outflow_lccfloutflowmass)
          topdown_outflow_lccfloutflowmass =0;
        end
        if m==1
        topdown_lccfloutflowmass_withP = topdown_lccfloutflowmass_withP+topdown_outflow_lccfloutflowmass*(P_lccfl(m));
        else
            topdown_lccfloutflowmass_withP = topdown_lccfloutflowmass_withP+(topdown_outflow_lccfloutflowmass*(P_lccfl(m)-P_lccfl(m-1)));
        end
         end
        add_this_yr_LCCFLOFMASS = [add_this_yr_LCCFLOFMASS;topdown_lccfloutflowmass_withP,i,Y];
        end
    COL_TOP_DOWN_LCCFLOUTFLOW_MASS  = [COL_TOP_DOWN_LCCFLOUTFLOW_MASS ;add_this_yr_LCCFLOFMASS];
end

%% LED Display wasteflow from each product

COL_YR = [min(New_allsheet.Year):1:max(New_allsheet.Year)]';
COL_TOP_DOWN_LLEDOUTFLOW_MASS = [];
x=[];

for i=prod_list'
    
   rows = (New_allsheet.ProductID_prod_sheet==i);
        vars = {'Maximum_Lifespan'};
        Max_Lifespan = min(New_allsheet{rows,vars}); 
        Mean_Lifespan= min (New_allsheet{rows,'Mean_Lifespan'}); 
       Std_dev_Lifespan= min (New_allsheet{rows,'Std_dev_Lifespan'});
XXX_lled =  1:Max_Lifespan;%X is min to max L
%generate probability of lifespan
x0 = [1 1];

options = optimset('Display','iter');
x= fsolve(@(x0) root2d(x0,Mean_Lifespan,Std_dev_Lifespan),x0,options);


P_lled = cdf('Weibull',XXX_lled,x(1),x(2));%x(1) is scale parameter,%x(2)is shape parameter
       
        start_yr = min(New_allsheet(New_allsheet.ProductID_prod_sheet==i,:).Year);
        end_yr = max(New_allsheet(New_allsheet.ProductID_prod_sheet==i,:).Year);
        add_this_yr_LLEDOFMASS=[];
        
        for Y=start_yr+1:1:end_yr
             topdown_lledoutflowmass_withP =0;
         for m = 1:length(P_lled)
        Yr_N= Y-XXX_lled(m);
        rows = (New_allsheet.ProductID_prod_sheet==i&New_allsheet.Year==Yr_N);
        vars_lled= {'LCD_module_LED_incomingmass'};
        topdown_outflow_lledoutflowmass = New_allsheet{rows,vars_lled};
        if isempty(topdown_outflow_lledoutflowmass)
          topdown_outflow_lledoutflowmass =0;
        end
        if m==1
        topdown_lledoutflowmass_withP = topdown_lledoutflowmass_withP+topdown_outflow_lledoutflowmass*(P_lled(m));
        else
            topdown_lledoutflowmass_withP = topdown_lledoutflowmass_withP+(topdown_outflow_lledoutflowmass*(P_lled(m)-P_lled(m-1)));
        end
         end
        add_this_yr_LLEDOFMASS = [add_this_yr_LLEDOFMASS;topdown_lledoutflowmass_withP,i,Y];
        end
    COL_TOP_DOWN_LLEDOUTFLOW_MASS  = [COL_TOP_DOWN_LLEDOUTFLOW_MASS ;add_this_yr_LLEDOFMASS];
end

%% Creating a table with annual material waste flow (high level-base metals, plastics and components) for each product 


HighlevelMat_Outflow_sheet = table(COL_TOP_DOWN_FeOUTFLOW_MASS(:,3),COL_TOP_DOWN_FeOUTFLOW_MASS(:,2),COL_TOP_DOWN_FeOUTFLOW_MASS (:,1),...
    COL_TOP_DOWN_AlOUTFLOW_MASS (:,1),COL_TOP_DOWN_CuOUTFLOW_MASS (:,1),COL_TOP_DOWN_PlasticsOUTFLOW_MASS (:,1), COL_TOP_DOWN_OmOUTFLOW_MASS (:,1),COL_TOP_DOWN_OtOUTFLOW_MASS (:,1),...
    COL_TOP_DOWN_PCBOUTFLOW_MASS (:,1),COL_TOP_DOWN_CRTOUTFLOW_MASS (:,1), COL_TOP_DOWN_LIBOUTFLOW_MASS (:,1),COL_TOP_DOWN_LCCFLOUTFLOW_MASS (:,1),COL_TOP_DOWN_LLEDOUTFLOW_MASS (:,1),...
   'VariableNames',{'Year' 'ProductID' 'Fe_outflow_US' 'Al_outflow_US' 'Cu_outflow_US' 'Plastics_outflow_US' 'Othermetals_outflow_US' 'Others_outflow_US'...
   'PCB_outflow_US' 'CRT_outflow_US' 'LIB_outflow_US' 'LCDCCFL_outflow_US' 'LCDLED_outflow_US'});

HighlevelMat_Outflow_sheet.Fe_outflow_US(isnan(HighlevelMat_Outflow_sheet.Fe_outflow_US)) = 0;
HighlevelMat_Outflow_sheet.Al_outflow_US(isnan(HighlevelMat_Outflow_sheet.Al_outflow_US)) = 0;
HighlevelMat_Outflow_sheet.Cu_outflow_US(isnan(HighlevelMat_Outflow_sheet.Cu_outflow_US)) = 0;
HighlevelMat_Outflow_sheet.Plastics_outflow_US(isnan(HighlevelMat_Outflow_sheet.Plastics_outflow_US)) = 0;
HighlevelMat_Outflow_sheet.Othermetals_outflow_US(isnan(HighlevelMat_Outflow_sheet.Othermetals_outflow_US)) = 0;
HighlevelMat_Outflow_sheet.Others_outflow_US(isnan(HighlevelMat_Outflow_sheet.Others_outflow_US)) = 0;
HighlevelMat_Outflow_sheet.PCB_outflow_US(isnan(HighlevelMat_Outflow_sheet.PCB_outflow_US)) = 0;
HighlevelMat_Outflow_sheet.CRT_outflow_US(isnan(HighlevelMat_Outflow_sheet.CRT_outflow_US)) = 0;
HighlevelMat_Outflow_sheet.LIB_outflow_US(isnan(HighlevelMat_Outflow_sheet.LIB_outflow_US)) = 0;
HighlevelMat_Outflow_sheet.LCDCCFL_outflow_US(isnan(HighlevelMat_Outflow_sheet.LCDCCFL_outflow_US)) = 0;
HighlevelMat_Outflow_sheet.LCDLED_outflow_US(isnan(HighlevelMat_Outflow_sheet.LCDLED_outflow_US)) = 0;
HighlevelMat_Outflow_sheet = HighlevelMat_Outflow_sheet(HighlevelMat_Outflow_sheet.Year > 1989,:);


%% Creating a table with cumulative material wasteflow (high level-base metals, plastics and components) from all products 

COL_TOTAL_FeOUTFLOW_MASS_SUM=[];
COL_TOTAL_AlOUTFLOW_MASS_SUM=[];
COL_TOTAL_CuOUTFLOW_MASS_SUM=[];
COL_TOTAL_PlasticsOUTFLOW_MASS_SUM=[];
COL_TOTAL_OmOUTFLOW_MASS_SUM=[];
COL_TOTAL_OtOUTFLOW_MASS_SUM=[];
COL_TOTAL_PCBOUTFLOW_MASS_SUM=[];
COL_TOTAL_CRTOUTFLOW_MASS_SUM=[];
COL_TOTAL_LIBOUTFLOW_MASS_SUM=[];
COL_TOTAL_LCCFLOUTFLOW_MASS_SUM=[];
COL_TOTAL_LLEDOUTFLOW_MASS_SUM=[];

start_yr_mat= min(HighlevelMat_Outflow_sheet.Year);
end_yr_mat = max(HighlevelMat_Outflow_sheet.Year);

     for i= start_yr_mat:1:end_yr_mat
        %%add_this_yr_totallead=[];
        total_Feoutflowmass_sum =0;
        total_Aloutflowmass_sum =0;
        total_Cuoutflowmass_sum =0;
         total_Plasticsoutflowmass_sum =0;
        total_Omoutflowmass_sum =0;
        total_Otoutflowmass_sum =0;
        total_PCBoutflowmass_sum =0;
        total_CRToutflowmass_sum =0;
        total_LIBoutflowmass_sum =0;
        total_LCCFLoutflowmass_sum =0;
        total_LLEDoutflowmass_sum =0;
        rows11 = (HighlevelMat_Outflow_sheet.Year==i);
        varsFe = {'Fe_outflow_US'};
        varsAl = {'Al_outflow_US'};
        varsCu = {'Cu_outflow_US'};
         varsPl = {'Plastics_outflow_US'};
         varsOm = {'Othermetals_outflow_US'};
          varsOt = {'Others_outflow_US'};
           varsPCB = {'PCB_outflow_US'};
            varsCRT = {'CRT_outflow_US'};
             varsLIB = {'LIB_outflow_US'};
              varsLCCFL = {'LCDCCFL_outflow_US'};
               varsLLED = {'LCDLED_outflow_US'};
        total_Feoutflowmass =nansum(HighlevelMat_Outflow_sheet{rows11,varsFe});
        total_Aloutflowmass =nansum(HighlevelMat_Outflow_sheet{rows11,varsAl});
        total_Cuoutflowmass =nansum(HighlevelMat_Outflow_sheet{rows11,varsCu});
         total_Plasticsoutflowmass =nansum(HighlevelMat_Outflow_sheet{rows11,varsPl});
         total_Omoutflowmass =nansum(HighlevelMat_Outflow_sheet{rows11,varsOm});
          total_Otoutflowmass =nansum(HighlevelMat_Outflow_sheet{rows11,varsOt});
           total_PCBoutflowmass =nansum(HighlevelMat_Outflow_sheet{rows11,varsPCB});
            total_CRToutflowmass =nansum(HighlevelMat_Outflow_sheet{rows11,varsCRT});
             total_LIBoutflowmass =nansum(HighlevelMat_Outflow_sheet{rows11,varsLIB});
             total_LCCFLoutflowmass =nansum(HighlevelMat_Outflow_sheet{rows11,varsLCCFL});
             total_LLEDoutflowmass =nansum(HighlevelMat_Outflow_sheet{rows11,varsLLED});
     if isnan(total_Feoutflowmass)
        total_Feoutflowmass =0;
     end
     if isnan(total_Aloutflowmass)
       total_Aloutflowmass =0;
     end
     if isnan(total_Cuoutflowmass)
       total_Cuoutflowmass =0;
     end
     if isnan(total_Plasticsoutflowmass)
       total_Plasticsoutflowmass =0;
     end
     if isnan(total_Omoutflowmass)
       total_Omoutflowmass =0;
     end
     if isnan(total_Otoutflowmass)
       total_Otoutflowmass =0;
     end
     if isnan(total_PCBoutflowmass)
       total_PCBoutflowmass =0;
     end
     if isnan(total_CRToutflowmass)
       total_CRToutflowmass =0;
     end
     if isnan(total_LIBoutflowmass)
       total_LIBoutflowmass =0;
     end
     if isnan(total_LCCFLoutflowmass)
       total_LCCFLoutflowmass =0;
     end
     if isnan(total_LLEDoutflowmass)
       total_LLEDoutflowmass =0;
     end
       
     total_Feoutflowmass_sum = total_Feoutflowmass_sum + total_Feoutflowmass;
     total_Aloutflowmass_sum = total_Aloutflowmass_sum + total_Aloutflowmass;
     total_Cuoutflowmass_sum = total_Cuoutflowmass_sum + total_Cuoutflowmass;
       total_Plasticsoutflowmass_sum = total_Plasticsoutflowmass_sum + total_Plasticsoutflowmass;
      total_Omoutflowmass_sum = total_Omoutflowmass_sum + total_Omoutflowmass;
       total_Otoutflowmass_sum = total_Otoutflowmass_sum + total_Otoutflowmass;
        total_PCBoutflowmass_sum = total_PCBoutflowmass_sum + total_PCBoutflowmass;
         total_CRToutflowmass_sum = total_CRToutflowmass_sum + total_CRToutflowmass;
          total_LIBoutflowmass_sum = total_LIBoutflowmass_sum + total_LIBoutflowmass;
           total_LCCFLoutflowmass_sum = total_LCCFLoutflowmass_sum + total_LCCFLoutflowmass;
            total_LLEDoutflowmass_sum = total_LLEDoutflowmass_sum + total_LLEDoutflowmass;
     
     
     COL_TOTAL_FeOUTFLOW_MASS_SUM=[COL_TOTAL_FeOUTFLOW_MASS_SUM;i,total_Feoutflowmass_sum];
     COL_TOTAL_AlOUTFLOW_MASS_SUM=[COL_TOTAL_AlOUTFLOW_MASS_SUM;i,total_Aloutflowmass_sum];
     COL_TOTAL_CuOUTFLOW_MASS_SUM=[COL_TOTAL_CuOUTFLOW_MASS_SUM;i,total_Cuoutflowmass_sum];
      COL_TOTAL_PlasticsOUTFLOW_MASS_SUM=[COL_TOTAL_PlasticsOUTFLOW_MASS_SUM;i,total_Plasticsoutflowmass_sum];
     COL_TOTAL_OmOUTFLOW_MASS_SUM=[COL_TOTAL_OmOUTFLOW_MASS_SUM;i,total_Omoutflowmass_sum];
     COL_TOTAL_OtOUTFLOW_MASS_SUM=[COL_TOTAL_OtOUTFLOW_MASS_SUM;i,total_Otoutflowmass_sum];
     COL_TOTAL_PCBOUTFLOW_MASS_SUM=[COL_TOTAL_PCBOUTFLOW_MASS_SUM;i,total_PCBoutflowmass_sum];
     COL_TOTAL_CRTOUTFLOW_MASS_SUM=[COL_TOTAL_CRTOUTFLOW_MASS_SUM;i,total_CRToutflowmass_sum];
     COL_TOTAL_LIBOUTFLOW_MASS_SUM=[COL_TOTAL_LIBOUTFLOW_MASS_SUM;i,total_LIBoutflowmass_sum];
     COL_TOTAL_LCCFLOUTFLOW_MASS_SUM=[COL_TOTAL_LCCFLOUTFLOW_MASS_SUM;i,total_LCCFLoutflowmass_sum];
     COL_TOTAL_LLEDOUTFLOW_MASS_SUM=[COL_TOTAL_LLEDOUTFLOW_MASS_SUM;i,total_LLEDoutflowmass_sum];
     end 

TotalHighLevel_Mat_OFsheet = table( COL_TOTAL_FeOUTFLOW_MASS_SUM(:,1), COL_TOTAL_FeOUTFLOW_MASS_SUM(:,2),  COL_TOTAL_AlOUTFLOW_MASS_SUM(:,2), COL_TOTAL_CuOUTFLOW_MASS_SUM(:,2),...
    COL_TOTAL_PlasticsOUTFLOW_MASS_SUM(:,2), COL_TOTAL_OmOUTFLOW_MASS_SUM(:,2), COL_TOTAL_OtOUTFLOW_MASS_SUM(:,2), COL_TOTAL_PCBOUTFLOW_MASS_SUM(:,2), COL_TOTAL_CRTOUTFLOW_MASS_SUM(:,2), COL_TOTAL_LIBOUTFLOW_MASS_SUM(:,2),...
     COL_TOTAL_LCCFLOUTFLOW_MASS_SUM(:,2),COL_TOTAL_LLEDOUTFLOW_MASS_SUM(:,2),...
   'VariableNames',{'Year' 'TotalFe_outflow_US' 'TotalAl_outflow_US' 'TotalCu_outflow_US' 'TotalPlastics_outflow_US' 'TotalOthermetals_outflow_US' 'TotalOthers_outflow_US' 'TotalPCB_outflow_US' 'TotalCRTGlass_outflow_US'...
   'TotalLIB_outflow_US' 'TotalLCD_CCFL_outflow_US' 'TotalLCD_LED_outflow_US'});

writetable(TotalHighLevel_Mat_OFsheet,'MFAOUTPUT Total Material and Component wasteflows .xls');

%% Create Tbale and spreadsheet for highlevel material MFA

New_allsheet1 = New_allsheet(New_allsheet.Year > 1989,:);
New_allsheet1.Properties.VariableNames{'ProductID_prod_sheet'}='ProductID';
Highlevel_Materialflow_sheet= outerjoin(New_allsheet1,HighlevelMat_Outflow_sheet);
writetable(Highlevel_Materialflow_sheet,'MFAOUTPUT Material and Component flows.xls');

%% MFA TO ESTIMATE WASTEFLOWS OF MATERIALS OF INTEREST


%% MFA TO ESTIMATE WASTEFLOWS OF TOXIC MATERIALS: LEAD & MERCURY



New_allsheet.LCD_module_CCFL_incomingmass (isnan(New_allsheet.LCD_module_CCFL_incomingmass)) = 0;
New_allsheet.LCD_module_LED_incomingmass(isnan(New_allsheet.LCD_module_LED_incomingmass)) = 0;
New_allsheet.Flatpanelglass_incomingmass=New_allsheet.LCD_module_CCFL_incomingmass +New_allsheet.LCD_module_LED_incomingmass;
New_allsheet_targetmaterial = outerjoin(New_allsheet,Subcomponent_sheet);
New_allsheet_targetmaterial.leadPCBincomingmass=New_allsheet_targetmaterial.PCB_Incomingmass.*New_allsheet_targetmaterial.Pb_PCB;
New_allsheet_targetmaterial.leadCRTincomingmass=New_allsheet_targetmaterial.CRTGlass_incomingmass.*New_allsheet_targetmaterial.Pb_CRT;


%% LEAD

%%  MFA to estimate lead wasteflow from PCBs

COL_YR = [min(New_allsheet_targetmaterial.Year_New_allsheet):1:max(New_allsheet_targetmaterial.Year_New_allsheet)]';
COL_TOP_DOWN_PCBLEADOUTFLOW_MASS = [];
x=[];

for i=prod_list'
    
   rows = (New_allsheet_targetmaterial.ProductID_prod_sheet==i);
        vars = {'Maximum_Lifespan'};
        Max_Lifespan = min(New_allsheet_targetmaterial{rows,vars}); 
        Mean_Lifespan= min (New_allsheet_targetmaterial{rows,'Mean_Lifespan'}); 
       Std_dev_Lifespan= min (New_allsheet_targetmaterial{rows,'Std_dev_Lifespan'});
XXX =  1:Max_Lifespan;%X is min to max L
%generate probability of lifespan
x0 = [1 1];

options = optimset('Display','iter');
x= fsolve(@(x0) root2d(x0,Mean_Lifespan,Std_dev_Lifespan),x0,options);

%x= fsolve(@root2d,x0,options);

P_l = cdf('Weibull',XXX,x(1),x(2));%x(1) is scale parameter,%x(2)is shape parameter
% P = cdf('Lognormal',X,x(1),x(2));       
        start_yr = min(New_allsheet_targetmaterial(New_allsheet_targetmaterial.ProductID_prod_sheet==i,:).Year_New_allsheet);
        end_yr = max(New_allsheet_targetmaterial(New_allsheet_targetmaterial.ProductID_prod_sheet==i,:).Year_New_allsheet);
        add_this_yr_topdownleadOFMASS=[];
        
        for Y=start_yr+1:1:end_yr
             topdown_leadoutflowmass_withP =0;
         for m = 1:length(P_l)
        Yr_N= Y-XXX(m);
        rows = (New_allsheet_targetmaterial.ProductID_prod_sheet==i&New_allsheet_targetmaterial.Year_New_allsheet==Yr_N);
        vars1 = {'leadPCBincomingmass'};
        topdown_outflow_leadoutflowmass = New_allsheet_targetmaterial{rows,vars1};
        if isempty(topdown_outflow_leadoutflowmass)
          topdown_outflow_leadoutflowmass =0;
        end
        if m==1
        topdown_leadoutflowmass_withP = topdown_leadoutflowmass_withP+topdown_outflow_leadoutflowmass*(P_l(m));
        else
            topdown_leadoutflowmass_withP = topdown_leadoutflowmass_withP+(topdown_outflow_leadoutflowmass*(P_l(m)-P_l(m-1)));
        end
         end
        add_this_yr_topdownleadOFMASS = [add_this_yr_topdownleadOFMASS;topdown_leadoutflowmass_withP,i,Y];
        end
    COL_TOP_DOWN_PCBLEADOUTFLOW_MASS  = [COL_TOP_DOWN_PCBLEADOUTFLOW_MASS ;add_this_yr_topdownleadOFMASS];
end

%%  MFA to estimate lead wasteflow from CRT TVs and CRT Monitors

COL_TOP_DOWN_CRTLEADOUTFLOW_MASS = [];
x=[];

for i=prod_list'
    
   rows = (New_allsheet_targetmaterial.ProductID_prod_sheet==i);
        vars = {'Maximum_Lifespan'};
        Max_Lifespan = min(New_allsheet_targetmaterial{rows,vars}); 
        Mean_Lifespan= min (New_allsheet_targetmaterial{rows,'Mean_Lifespan'}); 
       Std_dev_Lifespan= min (New_allsheet_targetmaterial{rows,'Std_dev_Lifespan'});
XXXX =  1:Max_Lifespan;%X is min to max L
%generate probability of lifespan
x0 = [1 1];

options = optimset('Display','iter');
x= fsolve(@(x0) root2d(x0,Mean_Lifespan,Std_dev_Lifespan),x0,options);

%x= fsolve(@root2d,x0,options);

P_l1 = cdf('Weibull',XXXX,x(1),x(2));%x(1) is scale parameter,%x(2)is shape parameter
% P = cdf('Lognormal',X,x(1),x(2));       
        start_yr = min(New_allsheet_targetmaterial(New_allsheet_targetmaterial.ProductID_prod_sheet==i,:).Year_New_allsheet);
        end_yr = max(New_allsheet_targetmaterial(New_allsheet_targetmaterial.ProductID_prod_sheet==i,:).Year_New_allsheet);
        add_this_yr_topdowncrtleadOFMASS=[];
        
        for Y=start_yr+1:1:end_yr
             topdown_crtleadoutflowmass_withP =0;
         for m = 1:length(P_l1)
        Yr_N= Y-XXXX(m);
        rows = (New_allsheet_targetmaterial.ProductID_prod_sheet==i&New_allsheet_targetmaterial.Year_New_allsheet==Yr_N);
        vars1 = {'leadCRTincomingmass'};
        topdown_outflow_crtleadoutflowmass = New_allsheet_targetmaterial{rows,vars1};
        if isempty(topdown_outflow_crtleadoutflowmass)
          topdown_outflow_crtleadoutflowmass =0;
        end
        if m==1
        topdown_crtleadoutflowmass_withP = topdown_crtleadoutflowmass_withP+topdown_outflow_crtleadoutflowmass*(P_l1(m));
        else
            topdown_crtleadoutflowmass_withP = topdown_crtleadoutflowmass_withP+(topdown_outflow_crtleadoutflowmass*(P_l1(m)-P_l1(m-1)));
        end
         end
        add_this_yr_topdowncrtleadOFMASS = [add_this_yr_topdowncrtleadOFMASS;topdown_crtleadoutflowmass_withP,i,Y];
        end
    COL_TOP_DOWN_CRTLEADOUTFLOW_MASS  = [COL_TOP_DOWN_CRTLEADOUTFLOW_MASS ;add_this_yr_topdowncrtleadOFMASS];
end

%% Total Lead Wasteflow

TotalLeadOutflow_sheet = table(COL_TOP_DOWN_CRTLEADOUTFLOW_MASS(:,1),COL_TOP_DOWN_PCBLEADOUTFLOW_MASS(:,1), COL_TOP_DOWN_PCBLEADOUTFLOW_MASS(:,2),COL_TOP_DOWN_PCBLEADOUTFLOW_MASS(:,3),...
   'VariableNames',{'CRTLead_outflow_US' 'PCBLead_outflow_US' 'ProductID' 'Year'});
TotalLeadOutflow_sheet.CRTLead_outflow_US(isnan(TotalLeadOutflow_sheet.CRTLead_outflow_US)) = 0;
TotalLeadOutflow_sheet.PCBLead_outflow_US(isnan(TotalLeadOutflow_sheet.PCBLead_outflow_US)) = 0;
TotalLeadOutflow_sheet.Totalleadoutflow=(TotalLeadOutflow_sheet.CRTLead_outflow_US)+(TotalLeadOutflow_sheet.PCBLead_outflow_US);
TotalLeadOutflow_sheet = TotalLeadOutflow_sheet(TotalLeadOutflow_sheet.Year > 1989,:);

% Finish lead calculations

%% MERCURY

%% MERCURY Inflows from LCD monitors and tvs

add_this_lcdmonitor_inflow =[];
for tlcdmonitor=1989:1:2018
rows= (prod_sheet.ProductID==13&prod_sheet.Year==tlcdmonitor);
vars={'Sales_mass'};
lcdmonitor_inflow = prod_sheet{rows,vars};
add_this_lcdmonitor_inflow= [add_this_lcdmonitor_inflow;lcdmonitor_inflow,tlcdmonitor];
end
add_this_lcdtv_inflow =[];
for tlcdtv=1989:1:2018
rows= (prod_sheet.ProductID==14&prod_sheet.Year==tlcdtv);
vars={'Sales_mass'};
lcdtv_inflow = prod_sheet{rows,vars};
add_this_lcdtv_inflow= [add_this_lcdtv_inflow;lcdtv_inflow,tlcdtv];
end

Mercury_lcdmonitortv_sheet = table(add_this_lcdtv_inflow(:,2),add_this_lcdtv_inflow(:,1),add_this_lcdmonitor_inflow(:,1),...
  'VariableNames',{'Year' 'LCDtv_inflowmass_US_kg' 'LCDmonitor_inflowmass_US_kg'});
Mercury_lcdmonitortv_sheet.LCDmonitor_lamp_inflowmass_US_kg=(Mercury_lcdmonitortv_sheet.LCDmonitor_inflowmass_US_kg).*0.0011;
Mercury_lcdmonitortv_sheet.LCDmonitor_mercury_inflowmass_US_low=(Mercury_lcdmonitortv_sheet.LCDmonitor_lamp_inflowmass_US_kg).*0.00040725;

Mercury_lcdmonitortv_sheet.LCDmonitor_mercury_inflowmass_US_high=(Mercury_lcdmonitortv_sheet.LCDmonitor_lamp_inflowmass_US_kg).*0.00040725;

Mercury_lcdmonitortv_sheet.LCDtv_lamp_inflowmass_US_kg=(Mercury_lcdmonitortv_sheet.LCDtv_inflowmass_US_kg).*0.012;
Mercury_lcdmonitortv_sheet.LCDtv_mercury_inflowmass_US_low=Mercury_lcdmonitortv_sheet.LCDtv_lamp_inflowmass_US_kg*0.00040725;
Mercury_lcdmonitortv_sheet.LCDtv_mercury_inflowmass_US_high=Mercury_lcdmonitortv_sheet.LCDtv_lamp_inflowmass_US_kg*0.00040725;

%% MERCURY Wasteflows from LCD Monitors

COL_TOP_DOWN_LCDMONITOR_MERCURY_MASS_LOW = [];
x=[];
   rows2=(prod_sheet.ProductID==13);
        vars2 = {'Maximum_Lifespan'};
        Max_Lifespan_Lm = min(prod_sheet{rows2,vars2}); 
        Mean_Lifespan_Lm= min(prod_sheet{rows2,'Mean_Lifespan'}); 
       Std_dev_Lifespan_Lm= min(prod_sheet{rows2,'Std_dev_Lifespan'});
XXXXX=  1:Max_Lifespan_Lm;%X is min to max L
%generate probability of lifespan
x0 = [1 1];

options = optimset('Display','iter');
x= fsolve(@(x0) root2d(x0,Mean_Lifespan_Lm,Std_dev_Lifespan_Lm),x0,options);

%x= fsolve(@root2d,x0,options);

P_Lm = cdf('Weibull',XXXXX,x(1),x(2));%x(1) is scale parameter,%x(2)is shape parameter
     
        start_yr = min(Mercury_lcdmonitortv_sheet.Year);
        end_yr = max(Mercury_lcdmonitortv_sheet.Year);
        add_this_yr_lcdmonitor_mercuryOFMASSlow=[];
        
        for Y_Lm=start_yr+1:1:end_yr
       
             lcdmonitor_mercuryoutflowmasslow_withP =0;
         for m = 1:length(P_Lm)
        Yr_NL= Y_Lm-XXXXX(m);
      
       rows_hg=(Mercury_lcdmonitortv_sheet.Year==Yr_NL);

       
       %%       Mercury wasteflow from lcdmonitors -low 

       vars_hg={'LCDmonitor_mercury_inflowmass_US_low'};
       lcdmonitor_mercuryinflowmass_low=Mercury_lcdmonitortv_sheet{rows_hg,vars_hg}; 
        if isempty( lcdmonitor_mercuryinflowmass_low)
       lcdmonitor_mercuryinflowmass_low =0;
        end
        if m==1
       lcdmonitor_mercuryoutflowmasslow_withP = lcdmonitor_mercuryoutflowmasslow_withP+ lcdmonitor_mercuryinflowmass_low*(P_Lm(m));
        else
          lcdmonitor_mercuryoutflowmasslow_withP = lcdmonitor_mercuryoutflowmasslow_withP+( lcdmonitor_mercuryinflowmass_low*(P_Lm(m)-P_Lm(m-1)));
        end
        %%add_this_yr_lcdmonitor_mercuryOFMASSlow = [add_this_yr_lcdmonitor_mercuryOFMASSlow;lcdmonitor_mercuryoutflowmasslow_withP,Y];
      
         end
         COL_TOP_DOWN_LCDMONITOR_MERCURY_MASS_LOW  = [COL_TOP_DOWN_LCDMONITOR_MERCURY_MASS_LOW ;lcdmonitor_mercuryoutflowmasslow_withP,Y_Lm];

        end
        
  
%%      Mercury wasteflow from lcdmonitors -high
COL_TOP_DOWN_LCDMONITOR_MERCURY_MASS_HIGH  =[];
  start_yr = min(Mercury_lcdmonitortv_sheet.Year);
        end_yr = max(Mercury_lcdmonitortv_sheet.Year);
        add_this_yr_lcdmonitor_mercuryOFMASShigh=[];
        
        for Y_Lm=start_yr+1:1:end_yr
       
             lcdmonitor_mercuryoutflowmasshigh_withP =0;
         for m = 1:length(P_Lm)
        Yr_NL= Y_Lm-XXXXX(m);
      
       rows_hg=(Mercury_lcdmonitortv_sheet.Year==Yr_NL);
       vars_hg_mhigh={'LCDmonitor_mercury_inflowmass_US_high'};
       lcdmonitor_mercuryinflowmass_high=Mercury_lcdmonitortv_sheet{rows_hg,vars_hg_mhigh}; 
        if isempty( lcdmonitor_mercuryinflowmass_high)
       lcdmonitor_mercuryinflowmass_high =0;
        end
        if m==1
       lcdmonitor_mercuryoutflowmasshigh_withP = lcdmonitor_mercuryoutflowmasshigh_withP+ lcdmonitor_mercuryinflowmass_high*(P_Lm(m));
        else
          lcdmonitor_mercuryoutflowmasshigh_withP = lcdmonitor_mercuryoutflowmasshigh_withP+( lcdmonitor_mercuryinflowmass_high*(P_Lm(m)-P_Lm(m-1)));
        end
        
      
         end
         COL_TOP_DOWN_LCDMONITOR_MERCURY_MASS_HIGH  = [COL_TOP_DOWN_LCDMONITOR_MERCURY_MASS_HIGH ;lcdmonitor_mercuryoutflowmasshigh_withP,Y_Lm];

        end
        
  %% MERCURY Wasteflow from LCD TV

COL_TOP_DOWN_LCDTV_MERCURY_MASS_LOW = [];
x=[];
   rows3=(prod_sheet.ProductID==14);
        vars3 = {'Maximum_Lifespan'};
        Max_Lifespan_Lt = min(prod_sheet{rows3,vars3}); 
        Mean_Lifespan_Lt= min(prod_sheet{rows3,'Mean_Lifespan'}); 
       Std_dev_Lifespan_Lt= min(prod_sheet{rows3,'Std_dev_Lifespan'});
XXXXXt=  1:Max_Lifespan_Lt;%X is min to max L
%generate probability of lifespan
x0 = [1 1];

options = optimset('Display','iter');
x= fsolve(@(x0) root2d(x0,Mean_Lifespan_Lt,Std_dev_Lifespan_Lt),x0,options);

%x= fsolve(@root2d,x0,options);

P_Lt = cdf('Weibull',XXXXXt,x(1),x(2));%x(1) is scale parameter,%x(2)is shape parameter
     
        start_yr = min(Mercury_lcdmonitortv_sheet.Year);
        end_yr = max(Mercury_lcdmonitortv_sheet.Year);
        add_this_yr_lcdtv_mercuryOFMASSlow=[];
        
        for Y_Lt=start_yr+1:1:end_yr
       
             lcdtv_mercuryoutflowmasslow_withP =0;
         for m = 1:length(P_Lt)
        Yr_NLt= Y_Lt-XXXXXt(m);
      
       rows_hg=(Mercury_lcdmonitortv_sheet.Year==Yr_NLt);

       
       %%       Mercury wasteflow from lcdtv -low 

       vars_hg_tvlow={'LCDtv_mercury_inflowmass_US_low'};
       lcdtv_mercuryinflowmass_low=Mercury_lcdmonitortv_sheet{rows_hg,vars_hg_tvlow}; 
        if isempty( lcdtv_mercuryinflowmass_low)
       lcdtv_mercuryinflowmass_low =0;
        end
        if m==1
       lcdtv_mercuryoutflowmasslow_withP = lcdtv_mercuryoutflowmasslow_withP+ lcdtv_mercuryinflowmass_low*(P_Lt(m));
        else
          lcdtv_mercuryoutflowmasslow_withP = lcdtv_mercuryoutflowmasslow_withP+( lcdtv_mercuryinflowmass_low*(P_Lt(m)-P_Lt(m-1)));
        end
       
      
         end
         COL_TOP_DOWN_LCDTV_MERCURY_MASS_LOW  = [COL_TOP_DOWN_LCDTV_MERCURY_MASS_LOW ;lcdtv_mercuryoutflowmasslow_withP,Y_Lt];

        end
        
  %LCDtv wasteflow-high
  %%      Mercury wasteflow from lcdtv -high
  
COL_TOP_DOWN_LCDTV_MERCURY_MASS_HIGH  =[];
  start_yr = min(Mercury_lcdmonitortv_sheet.Year);
        end_yr = max(Mercury_lcdmonitortv_sheet.Year);
        add_this_yr_lcdtv_mercuryOFMASShigh=[];
        
        for Y_Lt=start_yr+1:1:end_yr
       
             lcdtv_mercuryoutflowmasshigh_withP =0;
         for m = 1:length(P_Lt)
        Yr_NLt= Y_Lt-XXXXXt(m);
      
       rows_hg=(Mercury_lcdmonitortv_sheet.Year==Yr_NLt);
       vars_hg_thigh={'LCDtv_mercury_inflowmass_US_high'};
       lcdtv_mercuryinflowmass_high=Mercury_lcdmonitortv_sheet{rows_hg,vars_hg_thigh}; 
        if isempty( lcdtv_mercuryinflowmass_high)
       lcdtv_mercuryinflowmass_high =0;
        end
        if m==1
       lcdtv_mercuryoutflowmasshigh_withP = lcdtv_mercuryoutflowmasshigh_withP+ lcdtv_mercuryinflowmass_high*(P_Lt(m));
        else
          lcdtv_mercuryoutflowmasshigh_withP = lcdtv_mercuryoutflowmasshigh_withP+( lcdtv_mercuryinflowmass_high*(P_Lt(m)-P_Lt(m-1)));
        end
        
      
         end
         COL_TOP_DOWN_LCDTV_MERCURY_MASS_HIGH  = [COL_TOP_DOWN_LCDTV_MERCURY_MASS_HIGH ;lcdtv_mercuryoutflowmasshigh_withP,Y_Lt];

        end
 
 
%Mercury all done


%% Total Material Wasteflow Table for lead and mercury

%% Lead
COL_TOTAL_LEADOUTFLOW_MASS_SUM=[];
start_yr_lead= min(TotalLeadOutflow_sheet.Year);
end_yr_lead = max(TotalLeadOutflow_sheet.Year);

     for i= start_yr_lead:1:end_yr_lead
        %%add_this_yr_totallead=[];
        total_leadoutflowmass_sum =0;
        rows1 = (TotalLeadOutflow_sheet.Year==i);
        vars1 = {'Totalleadoutflow'};
        total_leadoutflowmass =nansum(TotalLeadOutflow_sheet{rows1,vars1});
     if isnan(total_leadoutflowmass)
         total_leadoutflowmass =0;
     end
        %add_this_yr_totallead = add_this_yr_totallead + total_leadoutflowmass;
     total_leadoutflowmass_sum = total_leadoutflowmass_sum + total_leadoutflowmass;
     COL_TOTAL_LEADOUTFLOW_MASS_SUM  = [COL_TOTAL_LEADOUTFLOW_MASS_SUM ;i,total_leadoutflowmass_sum];
     end 
     
%% Creating a table for lead and mercury wasteflows

Mercury_Flow_Sheet = table( COL_TOP_DOWN_LCDMONITOR_MERCURY_MASS_LOW(:,2), COL_TOP_DOWN_LCDMONITOR_MERCURY_MASS_LOW(:,1),...
    COL_TOP_DOWN_LCDMONITOR_MERCURY_MASS_HIGH(:,1),COL_TOP_DOWN_LCDTV_MERCURY_MASS_LOW(:,1),COL_TOP_DOWN_LCDTV_MERCURY_MASS_HIGH(:,1),COL_TOTAL_LEADOUTFLOW_MASS_SUM(:,2),...
 'VariableNames',{ 'Year' 'LCDMonitor_Mercury_OF_Low' 'LCDMonitor_Mercury_OF_High' 'LCDTV_Mercury_OF_Low' 'LCDTV_Mercury_OF_High' 'LEAD_OF_Total'});
Mercury_Flow_Sheet.Mercury_OF_Low= Mercury_Flow_Sheet.LCDMonitor_Mercury_OF_Low+Mercury_Flow_Sheet.LCDTV_Mercury_OF_Low;
Mercury_Flow_Sheet.Mercury_OF_High=Mercury_Flow_Sheet.LCDMonitor_Mercury_OF_High+Mercury_Flow_Sheet.LCDTV_Mercury_OF_High;
      
writetable(Mercury_Flow_Sheet,'MFAOUTPUT_Lead_Mercury_Wasteflow.xls');



%% MFA TO ESTIMATE WASTEFLOWS OF VALUABLE METALS TO ESTIMATE MINING POTENTIAL : GOLD, INDIUM, COBALT

%% MFA TO ESTIMATE GOLD WASTEFLOWS

New_allsheet_targetmaterial.Gold_PCBincomingmass=New_allsheet_targetmaterial.PCB_Incomingmass.*New_allsheet_targetmaterial.Au_PCB;

COL_YR = [min(New_allsheet_targetmaterial.Year_New_allsheet):1:max(New_allsheet_targetmaterial.Year_New_allsheet)]';
COL_TOP_DOWN_GOLDOUTFLOW_MASS = [];
x=[];

for i=prod_list'
    
   rows = (New_allsheet_targetmaterial.ProductID_prod_sheet==i);
        vars_g = {'Maximum_Lifespan'};
        Max_Lifespan = min(New_allsheet_targetmaterial{rows,vars_g}); 
        Mean_Lifespan= min (New_allsheet_targetmaterial{rows,'Mean_Lifespan'}); 
       Std_dev_Lifespan= min (New_allsheet_targetmaterial{rows,'Std_dev_Lifespan'});
XXX_g =  1:Max_Lifespan;%X is min to max L
%generate probability of lifespan
x0 = [1 1];

options = optimset('Display','iter');
x= fsolve(@(x0) root2d(x0,Mean_Lifespan,Std_dev_Lifespan),x0,options);

%x= fsolve(@root2d,x0,options);

P_g = cdf('Weibull',XXX_g,x(1),x(2));%x(1) is scale parameter,%x(2)is shape parameter
% P = cdf('Lognormal',X,x(1),x(2));       
        start_yr = min(New_allsheet_targetmaterial(New_allsheet_targetmaterial.ProductID_prod_sheet==i,:).Year_New_allsheet);
        end_yr = max(New_allsheet_targetmaterial(New_allsheet_targetmaterial.ProductID_prod_sheet==i,:).Year_New_allsheet);
        add_this_yr_topdowngoldOFMASS=[];
        
        for Y=start_yr+1:1:end_yr
             topdown_goldoutflowmass_withP =0;
         for m = 1:length(P_g)
        Yr_N= Y-XXX_g(m);
        rows = (New_allsheet_targetmaterial.ProductID_prod_sheet==i&New_allsheet_targetmaterial.Year_New_allsheet==Yr_N);
        vars_gg = {'Gold_PCBincomingmass'};
        topdown_goldoutflowmass = New_allsheet_targetmaterial{rows,vars_gg};
        if isempty(topdown_goldoutflowmass)
          topdown_goldoutflowmass =0;
        end
        if m==1
        topdown_goldoutflowmass_withP =  topdown_goldoutflowmass_withP+topdown_goldoutflowmass*(P_g(m));
        else
           topdown_goldoutflowmass_withP = topdown_goldoutflowmass_withP+(topdown_goldoutflowmass*(P_g(m)-P_g(m-1)));
        end
         end
     add_this_yr_topdowngoldOFMASS = [add_this_yr_topdowngoldOFMASS;topdown_goldoutflowmass_withP,i,Y];
        end
    COL_TOP_DOWN_GOLDOUTFLOW_MASS = [COL_TOP_DOWN_GOLDOUTFLOW_MASS ;add_this_yr_topdowngoldOFMASS];
end

% Gold Wasteflow Sheet
Gold_Outflow_sheet = table(COL_TOP_DOWN_GOLDOUTFLOW_MASS(:,1), COL_TOP_DOWN_GOLDOUTFLOW_MASS(:,2),COL_TOP_DOWN_GOLDOUTFLOW_MASS(:,3),...
   'VariableNames',{'PCBGold_outflow_US' 'ProductID' 'Year'});
Gold_Outflow_sheet.PCBGold_outflow_US(isnan(Gold_Outflow_sheet.PCBGold_outflow_US)) = 0;
Gold_Outflow_sheet = Gold_Outflow_sheet(Gold_Outflow_sheet.Year > 1989,:);

% Total Gold flows from all products

COL_TOTAL_GOLDOUTFLOW_MASS_SUM=[];
start_yr_gold= min(Gold_Outflow_sheet.Year);
end_yr_gold = max(Gold_Outflow_sheet.Year);

     for i= start_yr_gold:1:end_yr_gold
        %%add_this_yr_totallead=[];
        total_goldoutflowmass_sum =0;
        rows1_g = (Gold_Outflow_sheet.Year==i);
        vars1_g = {'PCBGold_outflow_US'};
        total_goldoutflowmass =nansum(Gold_Outflow_sheet{rows1_g,vars1_g});
     if isnan(total_goldoutflowmass)
        total_goldoutflowmass =0;
     end
        %add_this_yr_totallead = add_this_yr_totallead + total_leadoutflowmass;
     total_goldoutflowmass_sum = total_goldoutflowmass_sum +  total_goldoutflowmass;
     COL_TOTAL_GOLDOUTFLOW_MASS_SUM = [COL_TOTAL_GOLDOUTFLOW_MASS_SUM;i,total_goldoutflowmass_sum];
     end 
     
% Finish Gold MFA

%% MFA TO ESTIMATE COBALT WASTEFLOWS

New_allsheet_targetmaterial.Cobalt_incomingmass=New_allsheet_targetmaterial.LIB_incomingmass.*New_allsheet_targetmaterial.Co_LIB;

COL_YR = [min(New_allsheet_targetmaterial.Year_New_allsheet):1:max(New_allsheet_targetmaterial.Year_New_allsheet)]';
COL_TOP_DOWN_COBALTOUTFLOW_MASS = [];
x=[];

for i=prod_list'
    
   rows = (New_allsheet_targetmaterial.ProductID_prod_sheet==i);
        vars_c = {'Maximum_Lifespan'};
        Max_Lifespan = min(New_allsheet_targetmaterial{rows,vars_c}); 
        Mean_Lifespan= min (New_allsheet_targetmaterial{rows,'Mean_Lifespan'}); 
       Std_dev_Lifespan= min (New_allsheet_targetmaterial{rows,'Std_dev_Lifespan'});
XXX_c =  1:Max_Lifespan;%X is min to max L
%generate probability of lifespan
x0 = [1 1];

options = optimset('Display','iter');
x= fsolve(@(x0) root2d(x0,Mean_Lifespan,Std_dev_Lifespan),x0,options);

%x= fsolve(@root2d,x0,options);

P_c = cdf('Weibull',XXX_c,x(1),x(2));%x(1) is scale parameter,%x(2)is shape parameter
% P = cdf('Lognormal',X,x(1),x(2));       
        start_yr = min(New_allsheet_targetmaterial(New_allsheet_targetmaterial.ProductID_prod_sheet==i,:).Year_New_allsheet);
        end_yr = max(New_allsheet_targetmaterial(New_allsheet_targetmaterial.ProductID_prod_sheet==i,:).Year_New_allsheet);
        add_this_yr_topdowncobaltOFMASS=[];
        
        for Y=start_yr+1:1:end_yr
             topdown_cobaltoutflowmass_withP =0;
         for m = 1:length(P_c)
        Yr_N= Y-XXX_c(m);
        rows = (New_allsheet_targetmaterial.ProductID_prod_sheet==i&New_allsheet_targetmaterial.Year_New_allsheet==Yr_N);
        vars_cc = {'Cobalt_incomingmass'};
        topdown_cobaltoutflowmass = New_allsheet_targetmaterial{rows,vars_cc};
        if isempty(topdown_cobaltoutflowmass)
          topdown_cobaltoutflowmass =0;
        end
        if m==1
     topdown_cobaltoutflowmass_withP =  topdown_cobaltoutflowmass_withP +topdown_cobaltoutflowmass*(P_c(m));
        else
          topdown_cobaltoutflowmass_withP  = topdown_cobaltoutflowmass_withP +(topdown_cobaltoutflowmass*(P_c(m)-P_c(m-1)));
        end
         end
      add_this_yr_topdowncobaltOFMASS= [ add_this_yr_topdowncobaltOFMASS;topdown_cobaltoutflowmass_withP,i,Y];
        end
 COL_TOP_DOWN_COBALTOUTFLOW_MASS = [COL_TOP_DOWN_COBALTOUTFLOW_MASS ; add_this_yr_topdowncobaltOFMASS];
end

% Cobalt Waste flow Sheet
Cobalt_Outflow_sheet = table( COL_TOP_DOWN_COBALTOUTFLOW_MASS(:,1),  COL_TOP_DOWN_COBALTOUTFLOW_MASS(:,2), COL_TOP_DOWN_COBALTOUTFLOW_MASS(:,3),...
   'VariableNames',{'Cobalt_LIB_outflow_US' 'ProductID' 'Year'});
Cobalt_Outflow_sheet.Cobalt_LIB_outflow_US(isnan(Cobalt_Outflow_sheet.Cobalt_LIB_outflow_US)) = 0;
Cobalt_Outflow_sheet = Cobalt_Outflow_sheet(Cobalt_Outflow_sheet.Year > 1989,:);

% Total Cobalt flows from all products

COL_TOTAL_COBALTOUTFLOW_MASS_SUM=[];
start_yr_cobalt= min(Cobalt_Outflow_sheet.Year);
end_yr_cobalt = max(Cobalt_Outflow_sheet.Year);

     for i= start_yr_cobalt:1:end_yr_cobalt
        %%add_this_yr_totallead=[];
        total_cobaltoutflowmass_sum =0;
        rows1_c = (Cobalt_Outflow_sheet.Year==i);
        vars1_c = {'Cobalt_LIB_outflow_US'};
        total_cobaltoutflowmass =nansum(Cobalt_Outflow_sheet{rows1_c,vars1_c});
     if isnan(total_cobaltoutflowmass)
        total_cobaltoutflowmass =0;
     end
        %add_this_yr_totallead = add_this_yr_totallead + total_leadoutflowmass;
     total_cobaltoutflowmass_sum = total_cobaltoutflowmass_sum + total_cobaltoutflowmass;
     COL_TOTAL_COBALTOUTFLOW_MASS_SUM = [COL_TOTAL_COBALTOUTFLOW_MASS_SUM;i,total_cobaltoutflowmass_sum];
     end 
     
% Finish Cobalt MFA

%% MFA TO ESTIMATE INDIUM WASTEFLOWS


New_allsheet_targetmaterial.Indium_incomingmass=New_allsheet_targetmaterial.Flatpanelglass_incomingmass.*New_allsheet_targetmaterial.In_LCD;

COL_YR = [min(New_allsheet_targetmaterial.Year_New_allsheet):1:max(New_allsheet_targetmaterial.Year_New_allsheet)]';
COL_TOP_DOWN_INDIUMOUTFLOW_MASS = [];
x=[];

for i=prod_list'
    
   rows = (New_allsheet_targetmaterial.ProductID_prod_sheet==i);
        vars_i = {'Maximum_Lifespan'};
        Max_Lifespan = min(New_allsheet_targetmaterial{rows,vars_i}); 
        Mean_Lifespan= min (New_allsheet_targetmaterial{rows,'Mean_Lifespan'}); 
       Std_dev_Lifespan= min (New_allsheet_targetmaterial{rows,'Std_dev_Lifespan'});
XXX_i =  1:Max_Lifespan;%X is min to max L
%generate probability of lifespan
x0 = [1 1];

options = optimset('Display','iter');
x= fsolve(@(x0) root2d(x0,Mean_Lifespan,Std_dev_Lifespan),x0,options);

%x= fsolve(@root2d,x0,options);

P_i = cdf('Weibull',XXX_i,x(1),x(2));%x(1) is scale parameter,%x(2)is shape parameter
% P = cdf('Lognormal',X,x(1),x(2));       
        start_yr = min(New_allsheet_targetmaterial(New_allsheet_targetmaterial.ProductID_prod_sheet==i,:).Year_New_allsheet);
        end_yr = max(New_allsheet_targetmaterial(New_allsheet_targetmaterial.ProductID_prod_sheet==i,:).Year_New_allsheet);
        add_this_yr_topdownindiumOFMASS=[];
        
        for Y=start_yr+1:1:end_yr
             topdown_indiumoutflowmass_withP =0;
         for m = 1:length(P_i)
        Yr_N= Y-XXX_i(m);
        rows = (New_allsheet_targetmaterial.ProductID_prod_sheet==i&New_allsheet_targetmaterial.Year_New_allsheet==Yr_N);
        vars_ii = {'Indium_incomingmass'};
        topdown_indiumoutflowmass = New_allsheet_targetmaterial{rows,vars_ii};
        if isempty(topdown_indiumoutflowmass)
          topdown_indiumoutflowmass =0;
        end
        if m==1
     topdown_indiumoutflowmass_withP =  topdown_indiumoutflowmass_withP +topdown_indiumoutflowmass*(P_i(m));
        else
          topdown_indiumoutflowmass_withP  = topdown_indiumoutflowmass_withP +(topdown_indiumoutflowmass*(P_i(m)-P_i(m-1)));
        end
         end
      add_this_yr_topdownindiumOFMASS= [ add_this_yr_topdownindiumOFMASS;topdown_indiumoutflowmass_withP,i,Y];
        end
 COL_TOP_DOWN_INDIUMOUTFLOW_MASS = [COL_TOP_DOWN_INDIUMOUTFLOW_MASS ; add_this_yr_topdownindiumOFMASS];
end

% Indium Wasteflow Sheet

Indium_Outflow_sheet = table( COL_TOP_DOWN_INDIUMOUTFLOW_MASS(:,1),  COL_TOP_DOWN_INDIUMOUTFLOW_MASS(:,2), COL_TOP_DOWN_INDIUMOUTFLOW_MASS(:,3),...
   'VariableNames',{'Indium_outflow_US' 'ProductID' 'Year'});
Indium_Outflow_sheet.Indium_outflow_US(isnan(Indium_Outflow_sheet.Indium_outflow_US)) = 0;
Indium_Outflow_sheet = Indium_Outflow_sheet(Indium_Outflow_sheet.Year > 1989,:);

% Total Indium flows from all products

COL_TOTAL_INDIUMOUTFLOW_MASS_SUM=[];
start_yr_indium= min(Indium_Outflow_sheet.Year);
end_yr_indium = max(Indium_Outflow_sheet.Year);

     for i= start_yr_indium:1:end_yr_indium
        %%add_this_yr_totallead=[];
        total_indiumoutflowmass_sum =0;
        rows1_i = (Indium_Outflow_sheet.Year==i);
        vars1_i = {'Indium_outflow_US'};
        total_indiumoutflowmass =nansum(Indium_Outflow_sheet{rows1_i,vars1_i});
     if isnan(total_indiumoutflowmass)
        total_indiumoutflowmass =0;
     end
        %add_this_yr_totallead = add_this_yr_totallead + total_leadoutflowmass;
     total_indiumoutflowmass_sum = total_indiumoutflowmass_sum + total_indiumoutflowmass;
     COL_TOTAL_INDIUMOUTFLOW_MASS_SUM = [COL_TOTAL_INDIUMOUTFLOW_MASS_SUM;i,total_indiumoutflowmass_sum];
     end 
     
% Finish Indium MFA

%% Create a tabble and spreadsheet for valuable material wasteflows

 %Creating single tabel with all critical metal OF flow data
CriticalMetal_OF_Sheet = table(COL_TOTAL_GOLDOUTFLOW_MASS_SUM(:,1),COL_TOTAL_GOLDOUTFLOW_MASS_SUM(:,2),COL_TOTAL_COBALTOUTFLOW_MASS_SUM(:,2),COL_TOTAL_INDIUMOUTFLOW_MASS_SUM(:,2),...
 'VariableNames',{'Year' 'Gold_wasteflow_US_kg' 'Cobalt_wasteflow_US_kg' 'Indium_wasteflow_US_kg'});
      
writetable(CriticalMetal_OF_Sheet,'MFAOUTPUT Au_In_Co Wasteflows.xls');

%% FINISH MFA






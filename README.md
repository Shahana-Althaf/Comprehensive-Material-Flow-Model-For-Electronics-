# Comprehensive-Material-Flow-Model-For-Electronics-
A matlab code for estimation of historic consumption and waste generation in electronics section

The historic material flow model for electronics calculates product inflows and waste flows in product units,
product mass as well as material flows based on yearly -sales, lifespan and product material composition data inputs.

The models takes .csv files as the input sheets.
Samples files (templates) for model inputs are uploaded with the codes. 
Input sheet (.csv files) with 
product details for the model should be named ‘Product_Details_Input’,
input sheet with product material profile should be named ‘Product_Material_Composition_Input’ 
and input sheet with special material composition data should be named ‘Component_Material_Composition_Input’.

Data dictionary for the input sheets for the models are given below:

DATA DICTIONARY FOR INPUT SHEETS

Product_Details_Input

Input sheet with product details has 10 columns:

Column 1: ProductID = Assign a number to each product. 
(Increment the number by one, when each product is entered, 
the maximum number in Product ID column indicates the number of products to be analyzed).

Column 2: Product Name =Enter Product Type.

Column 3: Year = Enter years starting when the product was first sold in United states to the latest year.

Column 4: Sales_units = Enter totals sales units in each year.

Column 5: AverageProductMass_kg = Enter average mass of the product sold in each year.

Column 6: Category= Enter the product category.

Column 7: Minimum_Lifespan= Enter any whole number other than zero (default= 1)

Column 8: Maximum_Lifespan= Enter any whole number other than zero (default= 10)

Column 9: Mean_Lifespan = Enter average product lifespan

Column 10: Std_dev_Lifespan = Enter standard deviation of product lifespan

Product_Material_Composition_Input

Input sheet with product material composition has 14 columns.

Column 1: ProductID = Assign a number to each product. 
(Increment the number by one, when each product is entered, 
the maximum number in Product ID column indicates the number of products to be analyzed.

Column 2: Product Name =Enter Product Type

Column 3: Year = Enter years starting when the product was first sold in United states to the latest year.

Column 4: Fe = Enter the ferrous metal composition in the product (kg/kg) in each year

Column 5: Al = Enter the aluminum composition in the product (kg/kg) in each year

Column 6: Cu= Enter the copper composition in the product (kg/kg) in each year

Column 7: Other_metals = Enter the miscellaneous metal composition in the product (kg/kg) in each year

Column 8: Plastics = Enter the plastic composition in the product (kg/kg) in each year

Column 9: PCB = Enter the printed circuit board composition in the product (kg/kg) in each year

Column 10: LCD_module_CCFL = Enter the display glass composition in LCD display products (kg/kg) in each year

Column 11: LCD_module_LED = Enter the display glass composition in LED display products (kg/kg) in each year

Column 12: CRT_Glass = Enter the CRT display glass composition in products (kg/kg) in each year

Column 13: Li_battery = Enter the battery composition in LCD display products (kg/kg) in each year

Column 14: Others = Enter other material composition in products (kg/kg) in each year

Component_Material_Composition_Input

Input sheet with specific  material composition in components has 7 columns:

Column 1: Year = Enter the years for which specific material waste flows are to be calculated.

Column 2: Au_PCB = Enter average gold composition in printed circuit boards (kg/kg) in each year

Column 3: Pb_PCB = Enter average lead composition in printed circuit boards (kg/kg) in each year

Column 4: Pb_CRT = Enter average lead composition in cathode ray tube glass (kg/kg) in each year

Column 5: In_LED = Enter average indium composition in liquid crystal display glass (kg/kg) in each year

Column 6: In_LCD = Enter average indium composition in liquid crystal display glass (kg/kg) in each year

Column 7: Co_LIB = Enter average cobalt composition in lithium ion batteries (kg/kg) in each year

MODEL OUTPUTS:

The model calculates waste flows by multiplying annual sales by product lifespan probability. 

Lifespan Distribution: The lifespan probability of products is assumed to follow a Weibull distribution function,
generated based on the parameters provided by the user.

The probability for a given range of lifespan is generated using the MATLAB function for cumulative distribution function 
for Weibull given as P = cdf ('Weibull', X, a, b) 
where X is the range of lifespan (minimum to maximum lifespan of the product), the probability of which is to be calculated, 
a is the shape parameter and b is the scale parameter. The models take minimum, maximum, mean and std deviation of lifespan, 
as inputs generate the Weibull cdf using the rood2d function. 
The model generates results in 5 different excel sheets. 
If only the product level input sheet (Product_Details_Input) is used,
only product level flow data will be generated in a excel sheet named as ‘MFAOUTPUT Product flows’.  
If ‘‘Product_Material_Composition_Input’ is used then material and component flows are reported in 2 separate 
spread sheets-  One output sheet reports material flows at product level (‘MFAOUTPUT Material and Component flows’) 
while the other one (‘MFAOUTPUT Total Material and Component wasteflows’) reports total material flows in each year. 
If specific material input sheet is used MFA results are reported in 2 separate sheets ‘MFAOUTPUT Au_In_Co Wasteflows’ 
and ‘MFAOUTPUT_Lead_Mercury_Wasteflow’.

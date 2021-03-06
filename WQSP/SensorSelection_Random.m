% Main Program to find the achieved error of Kalman filter given random
% locations

% System: only on Windows
% Matlab Version: R2019b
% Author: Shen Wang
% Date: 3/7/2020

function fileName2 = SensorSelection_Random(Network,SENSORSELECT,COMPARE,Hq_min,SimutionTimeInMinute,Expected_t)
%% Load EPANET MATLAB TOOLKIT
start_toolkit;

% check this example Toolkit_EX3_Minimum_chlorine_residual.m
%% run EPANET MATLAB TOOLKIT to obtain data

assert((SENSORSELECT || COMPARE) == 1, "One of them most be 1")

% Don't forget to add the corresponding code for a new netwrok in
% GenerateSegments4Pipes.m
sensorNumberArray = [];
switch Network
    case 1
        % Quality Timestep = 1 min, and  Global Bulk = -0.3, Global Wall= -0.0
        % NetworkName = 'Threenode-cl-2-paper.inp'; pipe flow direction
        % never changed, and the result is perfectly matched with EPANET
        %NetworkName = 'Threenode-cl-3-paper.inp'; % Pipe flow direction changes
        NetworkName = 'Threenode-cl-2-paper.inp'; % topogy changes
        filename = 'Three-node_1day.mat';
        sensorNumberArray = [1 2];
        numofGroups = 1; % how many groups of random locations
    case 2
        % Don't not use one: Quality Timestep = 5 min, and  Global Bulk = -0.3, Global Wall=
        % -1.0
        NetworkName = 'tutorial8node.inp';
    case 3
        % Quality Timestep = 1 min, and  Global Bulk = -0.3, Global Wall= -0.0
        NetworkName = 'tutorial8node1.inp';
    case 4
        % Quality Timestep = 1 min, and  Global Bulk = -0.3, Global Wall=
        % -0.0; initial value: J2 = 0.5 mg/L, J6 = 1.2 mg/L, R1 = 0.8 mg/L;
        % segment = 1000;
        NetworkName = 'tutorial8node1inital3.inp';
        filename = '8node_1day.mat';
        sensorNumberArray = [1 3 5];
        numofGroups = 1; % how many groups of random locations
    case 5
        % Quality Timestep = 1 min, and  Global Bulk = -0.5, Global Wall=
        % -0.0;
        NetworkName = 'Net1-1min.inp';
    case 6
        % The initial value is slightly different
        % Quality Timestep = 1 min, and  Global Bulk = -0.3, Global Wall= -0.0
        NetworkName = 'Net1-1min-demand-pattern3.inp';
        filename = 'Net1_1days_demand-pattern3.mat';
%         NetworkName = 'Net1-1min-demand-pattern1-basedemand1.inp';
%         filename = 'Net1_1days_demand-pattern1-basedemand1.mat';
        sensorNumberArray = [1 3 5];
        numofGroups = 3; % how many groups of random locations
    case 7
        % Quality Timestep = 1 min, and  Global Bulk = -0.3, Global Wall= -0.0
        NetworkName = 'Net1-1min-new-demand-pattern.inp';
        filename = 'Net1_1days.mat';
        sensorNumberArray = [1 3 5];
        numofGroups = 3; % how many groups of random locations
    case 8
        % Quality Timestep = 1 min, and  Global Bulk = -0.3, Global Wall= -0.0
        NetworkName = 'Fournode-Cl-As-1.inp';
    case 9
        %NetworkName = 'Net3-NH2CL-24hour-4.inp'; % this is used to test the topology changes
        NetworkName = 'Net3-NH2CL-24hour-13.inp';
        filename = 'Net3_1day.mat';
        sensorNumberArray = [2 8 14];
        numofGroups = 10; % how many groups of random locations
    otherwise
        disp('other value')
end

%% Generate random locations (3 groups)



%% Prepare constants data for MPC
PrepareData4SensorSelection
% nodePattern = d.getPattern;
% baseDemand = d.getNodeBaseDemands;
% define the number of segment, useless code, delete later
NumberofSegment = Constants4Concentration.NumberofSegment;

[SCell,indexCell] = gererateRandomLocation(sensorNumberArray,nodeCount,numofGroups);



%% initialize concentration at nodes

% initialize BOOSTER
% flow of Booster, assume we put booster at each nodes, so the size of it
% should be the number of nodes.



switch Network
    case 1
        Location_B = {'J2'}; % NodeID here;
        flowRate_B = [10]; % unit: GPM
        Price_B = [1];
        % the C_B is what we need find in MPC, useless here
        %C_B = [1]; % unit: mg/L % Concentration of booster
    case {2,3,4}
        Location_B = {'J3','J7'}; % NodeID here;
        flowRate_B = [10,10]; % unit: GPM
        Price_B = [1,1];
        % the C_B is what we need find in MPC, useless here
        %C_B = [1]; % unit: mg/L % Concentration of booster
    case {5,6,7}
        Location_B = {'J11','J22','J31'}; % NodeID here;
        flowRate_B = [10,10,10]; % unit: GPM
        Price_B = [1,1,1];
        % the C_B is what we need find in MPC, useless here
        %C_B = [1]; % unit: mg/L % Concentration of booster
    case 8
        Location_B = {'J2'}; % NodeID here;
        flowRate_B = [100]; % unit: GPM
        Price_B = [1];
    case 9
        Location_B = {'J10'}; % NodeID here;
        flowRate_B = [100]; % unit: GPM
        Price_B = [1];
    otherwise
        disp('other value')
end

[q_B,Price_B,BoosterLocationIndex,BoosterCount] = InitialBooster(nodeCount,Location_B,flowRate_B,NodeID,Price_B);

% Compute Quality without MSX
% (This function contains events) Don't uncomment this commands!!! Crash
% easily
qual_res = d.getComputedQualityTimeSeries; %Value x Node, Value x Link
LinkQuality = qual_res.LinkQuality;
NodeQuality = qual_res.NodeQuality;

% Initial Concentration
C0 = [NodeQuality(1,:) LinkQuality(1,:)];

%% Construct aux struct

aux = struct('NumberofSegment',NumberofSegment,...
    'NumberofSegment4Pipes',[],...
    'LinkLengthPipe',LinkLengthPipe,...
    'LinkDiameterPipe',LinkDiameterPipe,...
    'TankBulkReactionCoeff',TankBulkReactionCoeff,...
    'TankMassMatrix',TankMassMatrix,...
    'JunctionMassMatrix',JunctionMassMatrix,...
    'MassEnergyMatrix',MassEnergyMatrix,...
    'NodeNameID',{NodeNameID},...
    'LinkNameID',{LinkNameID},...
    'NodesConnectingLinksID',{NodesConnectingLinksID},...
    'COMPARE',COMPARE);

%% Start

StoreRoom = cell(2,1);
QsN_Control = []; 
QsL_Control = [];
T = []; 
PreviousSystemDynamicMatrix = []; 
X_estimated = []; 
PreviousDelta_t = []; 
JunctionActualDemand = []; 
Head = []; 
Flow = []; 
XX_estimated = [];
errorAchievedResult = cell(20,1);
Velocity = [];
Delta_t = [];
NpMatrix = [];
XX_estimated_Cell = cell(200,1);
IndexInVarCell = cell(200,1);
NumberofSegment4Pipes_all = [];

Amatrix = cell(1,20);
Cmatrix = cell(1,20);
tempCell = 1;
tempCell1 = 1;

PreviousValue = struct('PreviousDelta_t',PreviousDelta_t,...
    'PreviousSystemDynamicMatrix',PreviousSystemDynamicMatrix,...
    'PreviousNumberofSegment4Pipes',[],...
    'IndexInVarOld',[],...
    'X_estimated',X_estimated,...
    'U_C_B_eachStep',0,...
    'tInMin',0,...
    'UeachMinforEPANET',0);

d.openHydraulicAnalysis;
d.openQualityAnalysis;
d.initializeHydraulicAnalysis;
d.initializeQualityAnalysis;

tleft=1;
tInMin = 0;
delta_t = 0;

% profile on
tic
while (tleft>0 && tInMin < SimutionTimeInMinute && delta_t <= 60)
    t1 = d.runHydraulicAnalysis;
    t=d.runQualityAnalysis;
    
    % Obtain the actual Concentration
    QsN_Control=[QsN_Control; d.getNodeActualQuality];
    QsL_Control=[QsL_Control; d.getLinkQuality];
    Head=[Head; d.getNodeHydaulicHead];
    Flow=[Flow; d.getLinkFlows];
    TempDemand = d.getNodeActualDemand;
    JunctionActualDemand = [JunctionActualDemand; TempDemand(NodeJunctionIndex)];

    tInMin = t/60;
    if(mod(tInMin,Hq_min)==0)
        % 5 miniute is up, Calculate the New Control Action
        disp('Current time')
        tInMin
        PreviousValue.tInMin = tInMin;
        tInHour = tInMin/60
        
        CurrentVelocity = d.getLinkVelocity;
        CurrentVelocityPipe = CurrentVelocity(:,PipeIndex);
        Velocity = [Velocity CurrentVelocityPipe'];
        
        % obtain Pipe Reaction Coeffs
        PipeReactionCoeff = CalculatePipeReactionCoeff(CurrentVelocityPipe,LinkDiameterPipe,Kb_all,Kw_all,PipeIndex);
        
        % obtain the segments according to current velocity and link length
        if(mod(tInMin,60)==0)
            NumberofSegment4Pipes = generateDynamicSegments4Pipes(Network,LinkLengthPipe,CurrentVelocityPipe,Expected_t);
            PreviousValue.PreviousNumberofSegment4Pipes = NumberofSegment4Pipes;
        end
        
        NumberofSegment4Pipes_all = [NumberofSegment4Pipes_all; NumberofSegment4Pipes];
        % update corresponding structures
        [IndexInVar,aux] = updateStructures(IndexInVar,aux,ElementCount,NumberofSegment4Pipes);
        % the minium step length for all pipes
        delta_t = LinkLengthPipe./NumberofSegment4Pipes./CurrentVelocityPipe;
        
        delta_t = min(delta_t);
        Delta_t = [Delta_t delta_t'];
        delta_t = MakeDelta_tAsInteger(delta_t)
        
        CurrentFlow = d.getLinkFlows; CurrentHead = d.getNodeHydaulicHead; Volume = d.getNodeTankVolume;
        CurrentNodeTankVolume = Volume(NodeTankIndex);
        
        % Estimate Hp of concentration; basciall 5 mins = how many steps
        SetTimeParameter = Hq_min*Constants4Concentration.MinInSecond/delta_t;
        Np = round(SetTimeParameter)
        NpMatrix = [NpMatrix Np];
        
        CurrentValue = struct('CurrentVelocityPipe',CurrentVelocityPipe,...
            'CurrentNodeTankVolume',CurrentNodeTankVolume,...
            'CurrentFlow',CurrentFlow,...
            'CurrentHead',CurrentHead,...
            'delta_t',delta_t,...
            'PipeReactionCoeff',PipeReactionCoeff,...
            'Np',Np,...
            'tInMin',tInMin,...
            'SystemDynamicMatrix',[]);
        
        % obtain dynamic
        [A,B,C] = ObtainDynamicNew(CurrentValue,IndexInVar,aux,ElementCount,q_B); % zeroRate(A)
        
        Amatrix{1,tempCell} = A; Cmatrix{1,tempCell} = C;
        
        PreviousSystemDynamicMatrix = struct('A',A,'B',B,'C',C);
        
        % Update the current value
        CurrentValue.SystemDynamicMatrix = PreviousSystemDynamicMatrix;
        
        % save IndexInVar
        PreviousValue.IndexInVarOld = IndexInVar;
        %         PreviousValue.PreviousSystemDynamicMatrix = PreviousSystemDynamicMatrix;
        
        if(tInMin == 60)
            stophere = 1;
        end
        
        if(COMPARE)
            if(tInMin == 0)
                xx_estimated = InitialState_X(CurrentValue,IndexInVar,aux,ElementCount,C0);
                PreviousValue.X_estimated = xx_estimated(:,end);
                XX_estimated_Cell{tempCell1} = xx_estimated;
                IndexInVarCell{tempCell1} = IndexInVar;
                NumberofSegment4Pipes_all = [NumberofSegment4Pipes_all; NumberofSegment4Pipes];
                
                if(SENSORSELECT)
                    errorAchievedEach5mins = ErrorAchievedSensorPlacement_Random(SCell,CurrentValue,aux,ElementCount,PreviousValue,nodeCount,IndexInVar.NumberofX,Np,sensorNumberArray);
                    errorAchievedResult{tempCell} = errorAchievedEach5mins;
                end
                
                tempCell1 = tempCell1 + 1;
                xx_estimated = EstimateState_XX_SaveMem1(CurrentValue,aux,ElementCount,PreviousValue,Hq_min);
            else
                % Esitmate the concentration in all elements according to the system dynamics each 5 mins
                [PreviousValueFetched,StoreRoom] = cacheValue(tInMin/Hq_min,'fetch',StoreRoom);
                xx_estimated = EstimateState_XX_SaveMem1(CurrentValue,aux,ElementCount,PreviousValueFetched,Hq_min);
            end
            PreviousValue.X_estimated = xx_estimated(:,end);
            
            % save
            %             xx_estimated_scaled = scaleX1(xx_estimated,IndexInVar,NumberofSegment4Pipes,ElementCount,NumberofSegment4PipesStore);
            XX_estimated_Cell{tempCell1} = xx_estimated;
            IndexInVarCell{tempCell1} = IndexInVar;
            
        end
        
        if(SENSORSELECT && tInMin ~= 0)
            [PreviousValueFetched,StoreRoom] = cacheValue(tInMin/Hq_min,'fetch',StoreRoom);
            errorAchievedEach5mins = ErrorAchievedSensorPlacement_Random(SCell,CurrentValue,aux,ElementCount,PreviousValueFetched,nodeCount,IndexInVar.NumberofX,Np,sensorNumberArray);
            errorAchievedResult{tempCell} = errorAchievedEach5mins;
        end
        [~,StoreRoom] = cacheValue(tInMin/Hq_min,'save',StoreRoom,PreviousValue);
        tempCell = tempCell + 1;
        tempCell1 = tempCell1 + 1;
    end
    
    T=[T; t];
    tstep1 = d.nextHydraulicAnalysisStep;
    tstep = d.nextQualityAnalysisStep;
end
runningtime = toc
d.closeQualityAnalysis;
d.closeHydraulicAnalysis;
% p = profile('info')
% save myprofiledata p
% profile viewer
%%

%% Start to plot

disp('Summary:')
disp(['Compare is: ',num2str(COMPARE)]);
disp('Done!! Start to organize data')

NodeIndex = d.getNodeIndex;
LinkIndex = nodeCount+d.getLinkIndex;
NodeID4Legend = Variable_Symbol_Table2(NodeIndex,1);
LinkID4Legend = Variable_Symbol_Table2(LinkIndex,1);

figure
plot(QsN_Control);
legend(NodeID4Legend)
xlabel('Time (minute)')
ylabel('Concentrations at junctions (mg/L)')

figure
plot(QsL_Control);
legend(LinkID4Legend)
xlabel('Time (minute)')
ylabel('Concentrations in links (mg/L)')

figure
plot(JunctionActualDemand)
xlabel('Time (minute)')
ylabel('Demand at junctions (GPM)')

legend(NodeID4Legend)



figure
plot(Flow)
legend(LinkID4Legend)
xlabel('Time (minute)')
ylabel('Flow rates in links (GPM)')

if(COMPARE)
    % find average data;
    NumberofSegment4PipesNew = ones(1,PipeCount);
    X_Min_Average = scaleX2(XX_estimated_Cell,IndexInVarCell,NumberofSegment4Pipes_all,ElementCount,NumberofSegment4PipesNew);
    
    %scaleX1(xx_estimated,IndexInVar,NumberofSegment4Pipes,ElementCount,NumberofSegment4PipesStore)
    
    %mergePipeSegment(XX_estimated,IndexInVarStore,auxStore,ElementCount);
    
    X_Min_Average = X_Min_Average';
    X_node_control_result =  X_Min_Average(:,NodeIndex);
    X_link_control_result =  X_Min_Average(:,LinkIndex);
    X_Junction_control_result =  X_Min_Average(:,NodeJunctionIndex);
    % X_link_control_result =  X_Min_Average(:,LinkIndex);
    
    figure
    plot(X_node_control_result);
    legend(NodeID4Legend)
    xlabel('Time (minute)')
    ylabel('Concentrations at junctions (mg/L)')
    
    figure
    plot(X_link_control_result);
    legend(LinkID4Legend)
    xlabel('Time (minute)')
    ylabel('Concentrations in links (mg/L)')
    
    epanetResult1 = [NodeQuality LinkQuality];
    epanetResult = [QsN_Control QsL_Control];
    % note that the above are both from EPAENT, their result are a little bit
    % different. I believe this because they use different method to implement
    % this.
    
    LDEResult = [X_node_control_result X_link_control_result];
    %     LDEResult1 = updateLDEResult(LDEResult,IndexInVar,MassEnergyMatrix);
    
    
    %     Calculate_Error_EPANET_LDE(epanetResult1',LDEResult1');
    %      This is for control purpose
    filenameSplit = split(filename,'.');
    
    fileNameError = ['Network',num2str(Network),'_',num2str(COMPARE),'_',num2str(SENSORSELECT),'_',filenameSplit{1},'_','Expected',num2str(round(Expected_t)),'_',num2str(Hq_min),'min'];
    Calculate_Error_EPANET_LDE(epanetResult',LDEResult',fileNameError);
    
    % For large scale network, we compare them in group
    
    linkCount = d.getLinkCount;
    if(linkCount > 20)
        eachGroup = 10;
        numberOfGroups = ceil(linkCount/eachGroup);
        for i = 1:numberOfGroups
            range = ((i-1)*eachGroup+1):(i*eachGroup);
            if i == numberOfGroups
                range = ((i-1)*10+1):linkCount;
            end
            InterestedID = LinkID4Legend(range,:);
            InterestedID = InterestedID';
            LDEGroup = LDEResult(1:SimutionTimeInMinute,LinkIndex);
            %         plotInterestedComponents(InterestedID,LinkID4Legend,LDEGroup,'LDE');
            EPANETGroup = epanetResult1(1:SimutionTimeInMinute,LinkIndex);
            %         plotInterestedComponents(InterestedID,LinkID4Legend,EPANETGroup,'EPANET');
            Calculate_Error_EPANET_LDE_Group(InterestedID,LinkID4Legend,EPANETGroup,LDEGroup)
        end
    end
    
end

if(SENSORSELECT)
    fileName1 = ['Random_SensorSelction',num2str(Network),'_',num2str(COMPARE),'_',num2str(SENSORSELECT),'_',filenameSplit{1},'_','Expected',num2str(round(Expected_t)),'_',num2str(Hq_min),'min','.mat']
    save(fileName1,'errorAchievedResult')
end

fileName2 = ['Random_Network',num2str(Network),'_',num2str(COMPARE),'_',num2str(SENSORSELECT),'_',filenameSplit{1},'_','Expected',num2str(round(Expected_t)),'_',num2str(Hq_min),'min','.mat']
save(fileName2);


sound1 = load('gong.mat');
sound(sound1.y,sound1.Fs);
end


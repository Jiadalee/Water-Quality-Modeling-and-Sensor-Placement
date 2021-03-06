function plotSensoPostition_paper_3node(sensorNumebers,numberofSensorsEachLayer,time,rawData,NodeID4Legend,filename,Hq_min,SimutionTimeInMinute)
[~,nLayers] = size(numberofSensorsEachLayer);

% extend one more row and column.
M = ones(time+1,sensorNumebers+1,nLayers)*10;
imgCell = cell(nLayers,1);
for i = 1:nLayers
    imgFake = ones(time + 1,sensorNumebers + 1);
    img = ones(time,sensorNumebers) - rawData(:,:,nLayers - i + 1);%(randi(2,sensorNumebers,time)-1); % put the sensor selection data here
    imgFake(2:time+1,2:sensorNumebers+1) = img;
    imgCell{i} = img';
    M(:,:,i) =  imgFake;
end
hf2 = figure;

fontsize = 40;
ha = tight_subplot(1,nLayers,[.01 .05],[.25 .23],[.1 .01])
for ii = 1:nLayers
    axes(ha(ii)); 
    imagesc(imgCell{nLayers - ii + 1});
    hold on
    colormap(gray);
    set(gca, 'TickLabelInterpreter', 'latex','fontsize',fontsize);
    set(ha(ii).Title,'String',['$r = ',num2str(numberofSensorsEachLayer(1,ii)),'$']);
    ax = gca;
    ax.Title.Interpreter = 'latex';
end

hold on
% X axis
labelIndex = [];
everyHowManyHours = 6;
SimulationHour = SimutionTimeInMinute/60;
cellString = cell(1,int16(SimulationHour/everyHowManyHours)+1);
every60minutes = int16(everyHowManyHours*60/Hq_min);
temp = 1;

for i = 0:every60minutes:time
    labelIndex = [labelIndex i];
    cellString{temp} =  strcat(num2str(i*Hq_min/60),'h');
    temp = temp +1;
end
set(ha(1:end),'XTick',labelIndex);
set(ha(1:end),'XTickLabel',cellString,'fontsize',fontsize);
hold on


% Y axis
labelIndex = zeros(1,sensorNumebers);
%cellString = cell(1,sensorNumebers);
for i = 1:sensorNumebers
    labelIndex(i) = i*1.0;
    %cellString{i} =  strcat(num2str(i),'s');
end

cellString = NodeID4Legend;

set(ha(1),'YTick',labelIndex);
set(ha(1),'YTickLabel',cellString,'fontsize',fontsize);
set(ha(2:end),'YTickLabel','')

% filename = ['SS_Result4',filename];
% filename = 'Net1_SSPaper'
set(gcf,'PaperUnits','inches','PaperPosition',[0 0 10 3])
% set(gcf,'PaperUnits','inches','PaperPosition',[0 0 16 7])
print(hf2,filename,'-depsc2','-r300');
print(hf2,filename,'-dpng','-r300');
end



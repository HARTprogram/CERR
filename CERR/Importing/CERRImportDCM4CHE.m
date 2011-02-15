function CERRImportDCM4CHE()
% CERRImportDCM4CHE
% imports the DICOM data into CERR plan format. This function is based on
% the Java code dcm4che.
% written DK, WY
%
% Copyright 2010, Joseph O. Deasy, on behalf of the CERR development team.
% 
% This file is part of The Computational Environment for Radiotherapy Research (CERR).
% 
% CERR development has been led by:  Aditya Apte, Divya Khullar, James Alaly, and Joseph O. Deasy.
% 
% CERR has been financially supported by the US National Institutes of Health under multiple grants.
% 
% CERR is distributed under the terms of the Lesser GNU Public License. 
% 
%     This version of CERR is free software: you can redistribute it and/or modify
%     it under the terms of the GNU General Public License as published by
%     the Free Software Foundation, either version 3 of the License, or
%     (at your option) any later version.
% 
% CERR is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
% without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
% See the GNU General Public License for more details.
% 
% You should have received a copy of the GNU General Public License
% along with CERR.  If not, see <http://www.gnu.org/licenses/>.


global stateS
if ~isfield(stateS,'initDicomFlag')
    flag = init_ML_DICOM;
    if ~flag
        return;
    end
elseif isfield(stateS,'initDicomFlag') && ~stateS.initDicomFlag
    return;
end

% Get the path of the directory to be selected for import.
path = uigetdir(pwd','Select the DICOM directory to scan:');
pause(0.1);

if ~path
    disp('DICOM import aborted');
    return
end

tic;

hWaitbar = waitbar(0,'Scanning Directory Please wait...');
CERRStatusString('Scanning DICOM directory');

%wy
filesV = dir(path);
disp(path);
dirs = filesV([filesV.isdir]);
dirs(2) = [];
dirs(1).name = '';
dcmdirS = [];

patientNum = 1;

for i = 1:length(dirs)
    patient = scandir_mldcm(fullfile(path, dirs(i).name), hWaitbar, i);
    if ~isempty(patient)
        for j = 1:length(patient.PATIENT)
            dcmdirS.(['patient_' num2str(patientNum)]) = patient.PATIENT(j);
            patientNum = patientNum + 1;
        end
    end
end
if isempty(dcmdirS)
    close(hWaitbar);
    msgbox('There is no dicom data!','Application Info','warn');
    return;
end

close(hWaitbar);

selected = showDCMInfo(dcmdirS);
patNameC = fieldnames(dcmdirS);
if isempty(selected)
    return
elseif strcmpi(selected,'all')
    combinedDcmdirS = struct('STUDY',dcmdirS.(patNameC{1}).STUDY,'info',dcmdirS.(patNameC{1}).info);
    for i = 2:length(patNameC)
        for j = 1:length(dcmdirS.(patNameC{i}).STUDY.SERIES)
            combinedDcmdirS.STUDY.SERIES(end+1) = dcmdirS.(patNameC{i}).STUDY.SERIES(j);
        end
    end
    % Pass the java dicom structures to function to create CERR plan
    planC = dcmdir2planC(combinedDcmdirS);
else
    % Pass the java dicom structures to function to create CERR plan
    planC = dcmdir2planC(dcmdirS.(selected)); %wy
end

indexS = planC{end};

%-------------Store CERR version number---------------%
[version, date] = CERRCurrentVersion;
planC{indexS.header}.CERRImportVersion = [version, ', ', date];

toc;
save_planC(planC,planC{indexS.CERROptions});


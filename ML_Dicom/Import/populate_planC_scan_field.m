function dataS = populate_planC_scan_field(fieldname, dcmdir_PATIENT_STUDY_SERIES, type, seriesNum)
%"populate_planC_scan_field"
%   Given the name of a child field to planC{indexS.scan}, populates that
%   field based on the data contained in the dcmdir.PATIENT.STUDY.SERIES
%   structure passed in.  Type defines the type of series passed in.
%
%JRA 06/15/06
%YWU Modified 03/01/08
%
%Usage:
%   dataS = populate_planC_scan_field(fieldname, dcmdir_PATIENT_STUDY_SERIES);
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

%For easier handling.

global pPos;

SERIES = dcmdir_PATIENT_STUDY_SERIES;

%Default value for undefined fields.
dataS = '';

switch fieldname
    case 'scanArray'
        %dataS   = uint16([]);
        zValues = [];

        %Determine number of images
        nImages = length(SERIES.Data);
        %nImages = length(SERIES);

        hWaitbar = waitbar(0,'Loading Scan Data Please wait...');

        %Iterate over slices.
        for imageNum = 1:nImages

            IMAGE   = SERIES.Data(imageNum); % wy {} --> ()
            imgobj  = scanfile_mldcm(IMAGE.file);

            %Pixel Data
            %wy sliceV = dcm2ml_Element(imgobj.get(hex2dec('7FE00010')));
            sliceV = imgobj.getInts(org.dcm4che2.data.Tag.PixelData);

            %Rows
            nRows  = dcm2ml_Element(imgobj.get(hex2dec('00280010')));

            %Columns
            nCols  = dcm2ml_Element(imgobj.get(hex2dec('00280011')));

            %Image Position (Patient)
            imgpos = dcm2ml_Element(imgobj.get(hex2dec('00200032')));

            %Pixel Representation commented by wy
            pixRep = dcm2ml_Element(imgobj.get(hex2dec('00280103')));

            %Bits Allocated
            bitsAllocated = dcm2ml_Element(imgobj.get(hex2dec('00280100')));

            if bitsAllocated > 16
                error('Only 16 bits per scan pixel are supported')
            end

            switch pixRep
                case 0
                    if ischar(dataS)
                        if ~strcmpi(type, 'CT')
                            dataS = single([]);
                        else
                            dataS = uint16([]);
                        end
                    end
                    if strcmpi(type, 'CT')                        
                        sliceV = uint16(sliceV);
                    end
                    %Shape the slice.
                    slice2D = reshape(sliceV, [nCols nRows]);
                case 1
                    if ischar(dataS)
                        dataS = int16([]);
                    end
                    sliceV = int16(sliceV);
                    %Shape the slice.
                    slice2D = reshape(sliceV, [nCols nRows]);

            end
            if (strcmpi(type, 'PT')) || (strcmpi(type, 'PET')) %Compute SUV for PET scans
                dcmobj = scanfile_mldcm(IMAGE.file);
                dicomHeaderS = dcm2ml_Object(dcmobj);
                slice2D = calc_suv(dicomHeaderS, single(slice2D));
            elseif ~strcmpi(type, 'CT')
                slice2D = single(slice2D);
            end

            %Store zValue for sorting, converting DICOM mm to CERR cm and
            %inverting to match CERR's z direction.
            zValues(imageNum) = - imgpos(3) / 10;

            %Store the slice in the 3D matrix.
            dataS(:,:,imageNum) = slice2D';

            %Check the image orientation.
            imgOri = dcm2ml_Element(imgobj.get(hex2dec('00200037')));
            %Check patient position
            pPos = dcm2ml_Element(imgobj.get(hex2dec('00185100')));

            if (imgOri(1)==-1)
                dataS(:,:,imageNum) = flipdim(dataS(:,:,imageNum), 2);
            end
            if (imgOri(5)==-1)
                dataS(:,:,imageNum) = flipdim(dataS(:,:,imageNum), 1);
            end

            if isequal(pPos,'HFP') || isequal(pPos,'FFP')
                dataS(:,:,imageNum) = flipdim(dataS(:,:,imageNum), 1); %Similar flip as doseArray
            end

            clear imageobj;

            waitbar(imageNum/(nImages),hWaitbar, ['Loading scans from Series ' num2str(seriesNum) '. Please wait...']);
        end

        close(hWaitbar);
        pause(1);

        %Reorder 3D matrix based on zValues.
        [jnk, zOrder]       = sort(zValues);
        dataS(:,:,1:end)    = dataS(:,:,zOrder);

    case 'scanType'

    case 'scanInfo'
        %Determine number of images
        nImages = length(SERIES.Data);

        %Get scanInfo field names.
        scanInfoInitS = initializeScanInfo;
        names = fields(scanInfoInitS);

        zValues = [];

        hWaitbar = waitbar(0,'Loading Scan Info Please wait...');

        %Iterate over slices.
        for imageNum = 1:nImages

            IMAGE   = SERIES.Data(imageNum);  % wy {} --> ()
            imgobj  = scanfile_mldcm(IMAGE.file);

            %Image Position (Patient)
            imgpos = dcm2ml_Element(imgobj.get(hex2dec('00200032')));

            %Store zValue for sorting, converting DICOM mm to CERR cm and
            %inverting to match CERR's z direction.
            zValues(imageNum) = - imgpos(3) / 10;

            for i = 1:length(names)
                dataS(imageNum).(names{i}) = populate_planC_scan_scanInfo_field(names{i}, IMAGE, imgobj);
            end

            clear imageobj;

            waitbar(imageNum/(nImages),hWaitbar, ['Loading scans Info. ' 'Please wait...']);
        end
        close(hWaitbar);

        %Reorder scanInfo elements based on zValues.
        [jnk, zOrder]   = sort(zValues);
        dataS(1:end)    = dataS(zOrder);

    case 'uniformScanInfo'
        %Implementation is unnecessary.
    case 'scanArraySuperior'
        %Implementation is unnecessary.
    case 'scanArrayInferior'
        %Implementation is unnecessary.
    case 'thumbnails'
        %Implementation is unnecessary.
    case 'transM'
        %Implementation is unnecessary.
    case 'scanUID'
        %Series Instance UID
        %dataS = dcm2ml_Element(SERIES.info.get(hex2dec('0020000E')));
        %wy, use the frame of reference UID to associate dose to scan.
        IMAGE   = SERIES.Data(1); % wy {} --> ()
        imgobj  = scanfile_mldcm(IMAGE.file);
        dataS = char(imgobj.getString(org.dcm4che2.data.Tag.FrameofReferenceUID));

    otherwise
        %         warning(['DICOM Import has no methods defined for import into the planC{indexS.scan}.' fieldname ' field, leaving empty.']);
end
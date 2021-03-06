function varargout = drawContour(command, varargin)
%"drawContour"
%    Contouring callbacks for a single axis.
%
%JRA 6/23/04
%
%Usage:
%   To begin: drawContour('axis', hAxis);
%   To quit : drawContour('quit', hAxis);
%   Get Data: drawContour('getContours', hAxis);
%   preDraw : drawContour('setContours', hAxis, contour);
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

switch command
    
    case 'axis'
        %Specify the handle of an axis for contouring, setup callbacks.
        hAxis = varargin{1};
        hFig  = get(hAxis, 'parent');
        setappdata(hFig, 'contourAxisHandle', hAxis);
        setappdata(hAxis, 'contourV', {});
        setappdata(hAxis, 'contourV2', {});
        noneMode(hAxis);
        oldAxisProperties = get(hAxis); %Store these to return to original state. Think about this.
        oldFigureProperties = get(hFig);

        oldBtnDown = getappdata(hAxis, 'oldBtnDown');
        if isempty(oldBtnDown)
            oldBtnDown = get(hAxis, 'buttonDownFcn');
            setappdata(hAxis, 'oldBtnDown', oldBtnDown);
        end

        set(hAxis, 'buttonDownFcn', 'drawContour(''btnDownInAxis'')');
        set(hFig, 'WindowButtonUpFcn', 'drawContour(''btnUp'')');
        set(hFig, 'doublebuffer', 'on');

    case 'quit'
        %Removed passed axis from drawContour mode.
        hAxis = varargin{1};
        hFig  = get(hAxis, 'parent');
        noneMode(hAxis);
        setappdata(hAxis, 'contourV', []);
        setappdata(hAxis, 'contourV2', []);
        setappdata(hAxis, 'segment', []);
        setappdata(hAxis, 'clip', []);
        drawAll(hAxis);

        set(hAxis, 'buttonDownFcn', getappdata(hAxis, 'oldBtnDown'));
        setappdata(hAxis, 'oldBtnDown', []);
        set(hFig, 'WindowButtonUpFcn', '');
        set(hFig, 'doublebuffer', 'on');

    case 'getState'
        hAxis = varargin{1};
        varargout{1} = getappdata(hAxis)

    case 'setState'
        hAxis = varargin{1};
        state = varargin{2};
        fNames = fieldnames(state)
        for i=1:length(fNames)
            setappdata(hAxis, fNames{i}, getfield(state, fNames{i}));
        end
        drawAll(hAxis);

    case 'defaultMode'
        %Safely finish all currently edited stuff and return to nonemode.
        hAxis = varargin{1};
        closeSegment(hAxis);
        editNum = getappdata(hAxis, 'editNum');
        saveSegment(hAxis, editNum);
        noneMode(hAxis);

    case 'editMode'
        %Force edit mode.
        hAxis = varargin{1};
        editMode(hAxis);

    case 'editModeGE'
        %Force edit mode.
        hAxis = varargin{1};
        editModeGE(hAxis);
        
    case 'drawMode'
        %Force draw mode.
        hAxis = varargin{1};
        drawMode(hAxis);

    case 'threshMode'
        %Force threshold mode.
        hAxis = varargin{1};
        threshMode(hAxis);

    case 'reassignMode'
        %Force reassign mode.
        hAxis = varargin{1};
        reassignMode(hAxis);

    case 'getContours'
        %Return all contours drawn on this axis, in axis coordinates.
        hAxis = varargin{1};
        contourV = getappdata(hAxis, 'contourV');
        varargout{1} = contourV;

    case 'getContours2'
        %Return all contours2 drawn on this axis, in axis coordinates.
        hAxis = varargin{1};
        contourV2 = getappdata(hAxis, 'contourV2');
        varargout{1} = contourV2;

    case 'setContours'
        %Wipe out all stored contours for this axis, and replace with
        %input contours.  Input is cell array of [Nx2] coordinates.
        hAxis = varargin{1};
        contourV = varargin{2};
        setappdata(hAxis, 'contourV', contourV);
        noneMode(hAxis);

    case 'setContours2'
        %Wipe out all stored contours2 for this axis, and replace with
        %input contours.  Input is cell array of [Nx2] coordinates.
        hAxis = varargin{1};
        contourV2 = varargin{2};
        setappdata(hAxis, 'contourV2', contourV2);
        noneMode(hAxis);

    case 'btnDownInAxis'
        %The action taken depends on current state.
        hAxis = gcbo;
%         check if zoom is enabled
%         val = get(stateS.handle.zoom, 'value');
        isZoomON = stateS.zoomState;
        isWindowingON = stateS.scanWindowState;
        if isZoomON || isWindowingON 
            sliceCallBack('axisclicked')
            return
        end        

        %Arg, temporary tie to slice viewer! Remove later.
        try
            global stateS;
            if ~isequal(stateS.handle.CERRAxis(stateS.handle.currentAxis), hAxis)
                sliceCallBack('Focus', hAxis);
                return;
            end
        end

        hFig = get(gcbo, 'parent');
        clickType = get(hFig, 'SelectionType');
        lastClickType = getappdata(hFig, 'lastClickType');
        setappdata(hFig, 'lastClickType', clickType);
        mode = getappdata(hAxis, 'mode');

        %Setup axis for motion.
        set(hFig, 'WindowButtonMotionFcn', 'drawContour(''motionInFigure'')');

        %SWITCH OVER MODES.
        if strcmpi(mode,        'DRAW')
            if strcmpi(clickType, 'normal')
                %Left click: enter drawing mode and begin new contour.
                drawingMode(hAxis);
                cP = get(hAxis, 'currentPoint');
                addPoint(hAxis, cP(1,1), cP(1,2));
                drawSegment(hAxis);
            elseif strcmpi(clickType, 'extend') | (strcmpi(clickType, 'open') & strcmpi(lastClickType, 'extend'))
            elseif strcmpi(clickType, 'alt')
            end

        elseif strcmpi(mode,    'DRAWING')
            if strcmpi(clickType, 'normal')
                %Left click: add point to contour and redraw.
                cP = get(hAxis, 'currentPoint');
                addPoint(hAxis, cP(1,1), cP(1,2));
                drawSegment(hAxis);
            elseif strcmpi(clickType, 'extend') | (strcmpi(clickType, 'open') & strcmpi(lastClickType, 'extend'))            
            elseif strcmpi(clickType, 'alt')
                %Right click: close new contour and return to drawMode.
                set(hAxis,'UIContextMenu',[])
                segmentNum = length(getappdata(hAxis, 'contourV')) + 1;
                closeSegment(hAxis);
                saveSegment(hAxis, segmentNum);
                drawMode(hAxis);
            end

        elseif strcmpi(mode,    'EDIT')
            if strcmpi(clickType, 'normal')
            elseif strcmpi(clickType, 'extend') | (strcmpi(clickType, 'open') & strcmpi(lastClickType, 'extend'))                                
            elseif strcmpi(clickType, 'alt')
                %Right click: cycle through clips if they exist.
                toggleClips(hAxis);
                drawSegment(hAxis);
            end

        elseif strcmpi(mode,    'EDITING')
            if strcmpi(clickType, 'normal')
            elseif strcmpi(clickType, 'extend') | (strcmpi(clickType, 'open') & strcmpi(lastClickType, 'extend'))
            elseif strcmpi(clickType, 'alt')
                % elseif strcmpi(clickType, 'open')
            end

        elseif strcmpi(mode,    'THRESH');
            if strcmpi(clickType, 'normal')
                %Left click: run threshold.
                cP = get(hAxis, 'currentPoint');
                getThresh(hAxis, cP(1,1), cP(1,2));

            elseif strcmpi(clickType, 'extend') | (strcmpi(clickType, 'open') & strcmpi(lastClickType, 'extend'))
%                 do nothing
            elseif strcmpi(clickType, 'alt')
%                 do nothing
                threshMode(hAxis);
            end

        elseif strcmpi(mode,    'NONE')
            
        end

    case 'motionInFigure'
        %The action taken depends on current state.
        hFig        = gcbo;
        hAxis       = getappdata(hFig, 'contourAxisHandle');
        clickType   = get(hFig, 'SelectionType');
        if isempty(hAxis)
            return
        end
        mode        = getappdata(hAxis, 'mode');

        if strcmpi(mode,        'DRAWING')
            if strcmpi(clickType, 'normal')
                %Left click+motion: add point and redraw.
                cP = get(hAxis, 'currentPoint');
                addPoint(hAxis, cP(1,1), cP(1,2));
                drawSegment(hAxis);
            end

        elseif strcmpi(mode,    'EDITING')
            if strcmpi(clickType, 'normal')
                %Left click+motion: add point to clip and redraw.
                cP = get(hAxis, 'currentPoint');
                addClipPoint(hAxis, cP(1,1), cP(1,2));
                drawClip(hAxis);
            end
            
        elseif strcmpi(mode,    'EDITINGGE')
            if strcmpi(clickType, 'normal')
                %Left click+motion: add point to clip and redraw.
                cP = get(hAxis, 'currentPoint');
                                                       
                % Find the closest point on the segment to the current mouse click
                % Contour points for the selected segment
                segment = getappdata(hAxis, 'segment');
                xV = segment(:,1);
                yV = segment(:,2);
                
                x = cP(1,1);
                y = cP(1,2);
                
                distM = sepsq([xV(:) yV(:)]', [x; y]);
                [jnk, indMin] = min(distM);
                indMin0 = indMin;
                
                % Get indices on segment that are +-3 indices away from current point
                indicesAll = 1:length(xV);
                indicesAll = [indicesAll indicesAll];
                numVoxels1 = 30;
                numVoxels2 = 25;
                if indMin-numVoxels1 <= 0
                    indMin = indMin + length(xV);
                end
                indToFit = indicesAll([indMin-numVoxels1:indMin-numVoxels2, indMin+numVoxels2:indMin+numVoxels1]);
                xFit = xV([indToFit indMin0]);
                yFit = yV([indToFit indMin0]);
                P = polyfit(xFit,yFit,2);
                yNew = yV;
                xNew = xV;
                yNew(indicesAll([indMin-numVoxels2-1:indMin-1, indMin+1:indMin+numVoxels2-1])) = polyval(P,xV(indicesAll([indMin-numVoxels2-1:indMin-1, indMin+1:indMin+numVoxels2-1])));
                
                xNew(indMin0) = x;
                yNew(indMin0) = y;
                
                segmentNew(:,1) = xNew(:);
                segmentNew(:,2) = yNew(:);
                
                %addClipPoint(hAxis, cP(1,1), cP(1,2));
                %drawClip(hAxis);
                
                %xV() =
                %yV() =
                %contourV{segmentNum} = contourV;
                
                setappdata(hAxis, 'segment', segmentNew);
                
                drawSegment(hAxis);
                
                
            end            
        end

    case 'btnUp'
        %The action taken depends on current state.        
        hFig = gcbo;      
        hAxis = getappdata(hFig, 'contourAxisHandle');
        clickType = get(hFig, 'SelectionType');
        mode = getappdata(hAxis, 'mode');
        
        if strcmpi(mode, 'EDITING')
            connectClip(hAxis);       
            editMode(hAxis);
            toggleClips(hAxis);
            drawSegment(hAxis);
        end              
        set(hFig, 'WindowButtonMotionFcn', '');

    case 'contourClicked'
        hLine = gcbo;
        hAxis = get(gcbo, 'parent');
        hFig = get(hAxis, 'parent');
        clickType = get(hFig, 'SelectionType');
        lastClickType = getappdata(hFig, 'lastClickType');
        setappdata(hFig, 'lastClickType', clickType);
        mode = getappdata(hAxis, 'mode');

        %Setup axis for motion.
        set(hFig, 'WindowButtonMotionFcn', 'drawContour(''motionInFigure'')');

        %None Mode
        if strcmpi(mode, 'none')

            %Edit mode
        elseif strcmpi(mode,    'EDIT')
            if strcmpi(clickType, 'normal')
                %Left click: select this contour for editing and commence.
                contourV = getappdata(hAxis, 'contourV');
                segmentNum = getappdata(hAxis, 'editNum');
                segment = getappdata(hAxis, 'segment');
                if ~isempty(segment)
                    contourV{segmentNum} = segment;
                    setappdata(hAxis, 'contourV', contourV);
                    setappdata(hAxis, 'segment', segment);
                end

                if isequal(getappdata(hAxis, 'hSegment'), gcbo)
                    segmentNum = getappdata(hAxis, 'editNum');
                else
                    segmentNum = get(gcbo, 'userdata');
                end

                editingMode(hAxis, segmentNum);
                cP = get(hAxis, 'currentPoint');
                addClipPoint(hAxis, cP(1,1), cP(1,2));
                drawClip(hAxis);
                
            elseif strcmpi(clickType, 'alt')
                %nothing but think about cycling clips here?
            end
            
            %Edit mode GE
        elseif strcmpi(mode,    'EDITGE')
            %Left click: select this contour for editing and commence.
            contourV = getappdata(hAxis, 'contourV');
            segmentNum = getappdata(hAxis, 'editNum');
            segment = getappdata(hAxis, 'segment');
            if ~isempty(segment)
                contourV{segmentNum} = segment;
                setappdata(hAxis, 'contourV', contourV);
                setappdata(hAxis, 'segment', segment);
            end
            
            if isequal(getappdata(hAxis, 'hSegment'), gcbo)
                segmentNum = getappdata(hAxis, 'editNum');
            else
                segmentNum = get(gcbo, 'userdata');
            end
            
            editingModeGE(hAxis, segmentNum);   
            
            segment = getappdata(hAxis, 'segment');
            distM = sepsq(segment',segment');
            
            % Make segment-resolution fine
            for i = 1:length(segment(:,1))-1
                P = polyfit(segment(i:i+1,1),segment(i:i+1,2),1);
                N = distM(i,i+1)/0.2;
                N = ceil(N);
                xNewC{i} = [];
                yNewC{i} = [];
                if N > 1
                    xNew = linspace(segment(i,1),segment(i+1,1),N);
                    yNew = polyval(P,xNew);
                    xNewC{i} = xNew;
                    yNewC{i} = yNew;
                end
            end
            
            segmentNew = [];
            indStart = 1;
            for i = 1:length(xNewC)                
               if ~isempty(xNewC{i})
                   segmentNew(indStart:indStart+length(xNewC{i})-1,1) = xNewC{i};
                   segmentNew(indStart:indStart+length(yNewC{i})-1,2) = yNewC{i};
                   indStart = indStart + length(yNewC{i});
               else
                   segmentNew(indStart,:) = segment(i,:);
                   indStart = indStart + 1;
               end                          
            end
            
            setappdata(hAxis, 'segment', segmentNew);
            
            %cP = get(hAxis, 'currentPoint');
            
            %setappdata(hAxis, 'contourV', contourV);
            
            drawSegment(hAxis);            

            
            
        elseif strcmpi(mode,    'REASSIGN')
            contourV = getappdata(hAxis, 'contourV');
            contourV2 = getappdata(hAxis, 'contourV2');
            contourUD = get(gcbo, 'userdata');
            if iscell(contourUD)
                contourV{end+1} = contourV2{contourUD{2}};
                contourV2{contourUD{2}} = [];
            else
                contourV2{end+1} = contourV{contourUD};
                contourV{contourUD} = [];
            end
            setappdata(hAxis, 'contourV', contourV);
            setappdata(hAxis, 'contourV2', contourV2);
            reassignMode(hAxis);
        end

    case 'deleteSegment'
        %Delete selected segment if relevant and if in edit mode.
        hAxis = varargin{1};
        mode = getappdata(hAxis, 'mode');
        if strcmpi(mode, 'drawing')
            delSegment(hAxis);
            drawMode(hAxis);
        elseif strcmpi(mode, 'edit')
            delSegment(hAxis);
            editMode(hAxis);
        elseif strcmpi(mode, 'thresh')
            delSegment(hAxis);
            threshMode(hAxis);
        end

end


%MODE MANAGEMENT
function drawMode(hAxis)
%Next mouse click starts a new contour and goes to drawing mode.
contourV = getappdata(hAxis, 'contourV');
segment = getappdata(hAxis, 'segment');
setappdata(hAxis, 'segment', []);
if ~isempty(segment)
    editNum = getappdata(hAxis, 'editNum');
    contourV{editNum} = segment;
    setappdata(hAxis, 'contourV', contourV);
end
setappdata(hAxis, 'mode', 'draw');
editNum = length(contourV) + 1;
setappdata(hAxis, 'editNum', editNum);
hContour = getappdata(hAxis, 'hContour');
set(hContour, 'hittest', 'off');
drawSegment(hAxis);
drawContourV(hAxis);

function drawingMode(hAxis)
%While the button is down or for each click, points are added
%to the contour being drawn.  Right click exists drawing mode.
setappdata(hAxis, 'mode', 'drawing');
setappdata(hAxis, 'segment', []);

function reassignMode(hAxis)
%Draws all contours on the slice and makes them selectable.  When a
%contour is clicked, it is moved to the other contour's list.
setappdata(hAxis, 'mode', 'reassign');
drawContourV(hAxis);
drawContourV2(hAxis);
hContour = getappdata(hAxis, 'hContour');
hContour2 = getappdata(hAxis, 'hContour2');
set(hContour, 'hittest', 'on');
set(hContour2, 'hittest', 'on');

function editMode(hAxis)
%Draws all contours on the slice and makes them selectable.  When a
%contour is clicked, goes to editingMode and begins drawing a clip.
%If a previous clip has been drawn, right clicking toggles clips.
setappdata(hAxis, 'mode', 'edit');
drawContourV(hAxis);
drawSegment(hAxis);
setappdata(hAxis, 'clip', []);
drawClip(hAxis);
hContour = getappdata(hAxis, 'hContour');
set(hContour, 'hittest', 'on');

function editModeGE(hAxis)
%Draws all contours on the slice and makes them selectable.  When a
%contour is clicked, goes to editingMode and begins drawing a clip.
%If a previous clip has been drawn, right clicking toggles clips.
setappdata(hAxis, 'mode', 'editGE');
drawContourV(hAxis);
drawSegment(hAxis);
setappdata(hAxis, 'clip', []);
drawClip(hAxis);
hContour = getappdata(hAxis, 'hContour');
set(hContour, 'hittest', 'on');

function editingMode(hAxis, segmentNum)
%While the button is down, points are added to the clip being drawn.
%Lifting the mouse button goes to Edit/SelectingClip mode.
setappdata(hAxis, 'mode', 'editing');
setappdata(hAxis, 'clipToggles', {});
contourV = getappdata(hAxis, 'contourV');
segment = contourV{segmentNum};
contourV{segmentNum} = [];
setappdata(hAxis, 'contourV', contourV);
setappdata(hAxis, 'segment', segment);
setappdata(hAxis, 'editNum', segmentNum);
%         drawContourV(hAxis);
%         drawSegment(hAxis);  %Considering brining these back, changes
%         color dynamically.

function editingModeGE(hAxis, segmentNum)
%While the button is down, points are added to the clip being drawn.
%Lifting the mouse button goes to Edit/SelectingClip mode.
setappdata(hAxis, 'mode', 'editingGE');
setappdata(hAxis, 'clipToggles', {});
contourV = getappdata(hAxis, 'contourV');
segment = contourV{segmentNum};
contourV{segmentNum} = [];
setappdata(hAxis, 'contourV', contourV);
setappdata(hAxis, 'segment', segment);
setappdata(hAxis, 'editNum', segmentNum);
%         drawContourV(hAxis);
%         drawSegment(hAxis);  %Considering brining these back, changes
%         color dynamically.

function noneMode(hAxis)
% 	%Set noneMode
setappdata(hAxis, 'mode', 'none');
drawContourV(hAxis);
drawContourV2(hAxis);
drawSegment(hAxis);
hContour = getappdata(hAxis, 'hContour');
set(hContour, 'hittest', 'on');
clearUndoInfo(hAxis);


function threshMode(hAxis)
%Set threshMode
contourV = getappdata(hAxis, 'contourV');
segment = getappdata(hAxis, 'segment');
setappdata(hAxis, 'segment', []);
if ~isempty(segment)
    editNum = getappdata(hAxis, 'editNum');
    contourV{editNum} = segment;
    setappdata(hAxis, 'contourV', contourV);
end
setappdata(hAxis, 'mode', 'thresh');
editNum = length(contourV) + 1;
setappdata(hAxis, 'editNum', editNum);
hContour = getappdata(hAxis, 'hContour');
set(hContour, 'hittest', 'off');
drawSegment(hAxis);
drawContourV(hAxis);


%     function freezeMode(hAxis)
% 	%Freezes all callbacks, button down functions etc. Use in
% 	%conjunction with state saving and returning in order to transfer
% 	%control of axis to another routine, and to return control to this.




%CONTOURING FUNCTIONS
function addPoint(hAxis, x, y);
%Add a point to the existing segment, in axis coordinates.
segment = getappdata(hAxis, 'segment');
segment = [segment;[x y]];
setappdata(hAxis, 'segment', segment);

function closeSegment(hAxis)
%Close the current segment by linking the first and last points.
segment = getappdata(hAxis, 'segment');
if ~isempty(segment)
    firstPt = segment(1,:);
    segment = [segment;[firstPt]];
    setappdata(hAxis, 'segment', segment);
end

function saveSegment(hAxis, segmentNum)
%Save the current segment to the contourV, and exit drawmode.
segment = getappdata(hAxis, 'segment');
if ~isempty(segment)
    contourV = getappdata(hAxis, 'contourV');
    contourV{segmentNum} = segment;
    setappdata(hAxis, 'contourV', contourV);
    setappdata(hAxis, 'segment', []);    
end

function delSegment(hAxis)
%Delete the segment being edited.
setappdata(hAxis, 'segment', []);
drawAll(hAxis);


%CLIPOUT FUNCTIONS
function addClipPoint(hAxis, x, y);
%Add a point to the existing clipout line, in axis coordinates.
clip = getappdata(hAxis, 'clip');
clip = [clip;[x y]];
setappdata(hAxis, 'clip', clip);

function connectClip(hAxis)
%Connect the drawn clip to the existing segment, generating 3
%combinations of clip and old segment.
clip = getappdata(hAxis, 'clip');
segment = getappdata(hAxis, 'segment');
if ~isempty(segment)
    startCoord = clip(1,:);
    endCoord = clip(end,:);
    [jnk, startPt] = min(sepsq(segment', startCoord'));
    [jnk, endPt] = min(sepsq(segment', endCoord'));
    %             if ~isequal(startPt, endPt)
    part1 = segment(min(startPt, endPt):max(startPt, endPt), :);
    part2 = [segment(max(startPt, endPt):end,:);segment(1:min(startPt, endPt),:)];
    setappdata(hAxis, 'clipnum', 2); %mod...
    if startPt > endPt
        clipToggles{1} = [clip;part1;clip(1,:)];
        clipToggles{2} = [clip;flipud(part2);clip(1,:)];
        clipToggles{3} = segment;
    elseif startPt < endPt
        clipToggles{1} = [clip;flipud(part1);clip(1,:)];
        clipToggles{2} = [clip;part2;clip(1,:)];
        clipToggles{3} = segment;
    else
        clipToggles{1} = [clip;part1;clip(1,:)];
        clipToggles{2} = [clip;flipud(part2);clip(1,:)];
        clipToggles{3} = segment;
    end

    curveLength1 = 0;
    for i = 1:size(clipToggles{1},1) - 1
        curveLength1 = curveLength1 + sepsq(clipToggles{1}(i,:)', clipToggles{1}(i+1,:)');
    end

    curveLength2 = 0;
    for i = 1:size(clipToggles{2},1) - 1
        curveLength2 = curveLength2 + sepsq(clipToggles{2}(i,:)', clipToggles{2}(i+1,:)');
    end

    if curveLength2 > curveLength1
        tmp = clipToggles{1};
        clipToggles{1} = clipToggles{2};
        clipToggles{2} = tmp;
    end


    setappdata(hAxis, 'clipToggles', clipToggles);
else
    return;
end

function toggleClips(hAxis)
%Toggle between outcome clips.
clipNum = getappdata(hAxis, 'clipnum');
clipNum = mod(clipNum + 1,3);
setappdata(hAxis, 'clipnum', clipNum);
clipToggles = getappdata(hAxis, 'clipToggles');
clip = clipToggles{clipNum + 1};
setappdata(hAxis, 'segment', clip);

%DRAWING FUNCTIONS
function drawContourV(hAxis) %%Maybe set line hittest here?? based on mode??
%Redraw the contour associated with hAxis.
hContour = getappdata(hAxis, 'hContour');
try
    delete(hContour);
end
hContour = [];

contourV = getappdata(hAxis, 'contourV');
if ~isempty(contourV)
    for i = 1:length(contourV)
        segment = contourV{i};
        if ~isempty(segment)
            hContour = [hContour, line(segment(:,1), segment(:,2), 'color', 'blue', 'linewidth', 1.5, 'hittest', 'off', 'erasemode', 'normal', 'userdata', i, 'ButtonDownFcn', 'drawContour(''contourClicked'')', 'parent', hAxis)];
        end
    end
    setappdata(hAxis, 'hContour', hContour);
else
    setappdata(hAxis, 'hContour', []);
end

function drawContourV2(hAxis) %%Maybe set line hittest here?? based on mode??
%Redraw the contour associated with hAxis.
hContour2 = getappdata(hAxis, 'hContour2');
try
    delete(hContour2);
end
hContour2 = [];

contourV2 = getappdata(hAxis, 'contourV2');
if ~isempty(contourV2)
    for i = 1:length(contourV2)
        segment = contourV2{i};
        if ~isempty(segment)
            hContour2 = [hContour2, line(segment(:,1), segment(:,2), 'color', 'green', 'linewidth', 1.5, 'hittest', 'off', 'erasemode', 'normal', 'userdata', {2,i}, 'ButtonDownFcn', 'drawContour(''contourClicked'')', 'parent', hAxis)];
        end
    end
    setappdata(hAxis, 'hContour2', hContour2);
else
    setappdata(hAxis, 'hContour2', []);
end

function drawSegment(hAxis)
%Redraw the current segment associated with hAxis
hSegment = getappdata(hAxis, 'hSegment');
mode = getappdata(hAxis, 'mode');
try
    delete(hSegment);
end
hSegment = [];

segment = getappdata(hAxis, 'segment');
if ~isempty(segment) & strcmpi(mode, 'drawing')
    hSegment = line(segment(:,1), segment(:,2), 'color', 'red', 'hittest', 'off', 'erasemode', 'none', 'parent', hAxis, 'ButtonDownFcn', 'drawContour(''contourClicked'')');
    setappdata(hAxis, 'hSegment', hSegment);
elseif ~isempty(segment)
    hSegment = line(segment(:,1), segment(:,2), 'color', 'red', 'hittest', 'on', 'erasemode', 'normal', 'parent', hAxis, 'ButtonDownFcn', 'drawContour(''contourClicked'')');
    setappdata(hAxis, 'hSegment', hSegment);
else
    setappdata(hAxis, 'hSegment', []);
end

function drawClip(hAxis)
%Redraw the current clipout segment associated with hAxis.
hClip = getappdata(hAxis, 'hClip');
mode = getappdata(hAxis, 'mode');
try
    delete(hClip);
end
hClip = [];

clip = getappdata(hAxis, 'clip');
if ~isempty(clip) & strcmpi(mode, 'editing')
    hClip = line(clip(:,1), clip(:,2), 'color', 'red', 'hittest', 'off', 'erasemode', 'none', 'parent', hAxis);
    setappdata(hAxis, 'hClip', hClip);
elseif ~isempty(clip)
    hClip = line(clip(:,1), clip(:,2), 'color', 'red', 'hittest', 'off', 'erasemode', 'normal', 'parent', hAxis);
    setappdata(hAxis, 'hClip', hClip);
else
    setappdata(hAxis, 'hClip', []);
end

function drawAll(hAxis)
%Redraw all existing contour graphics.
drawContourV(hAxis);
drawContourV2(hAxis);
drawSegment(hAxis);
drawClip(hAxis);

%THRESHOLDING FUNCTIONS

function getThresh(hAxis, x, y);
%Sets the current segment to the contour of connected region x,y
global planC
global stateS
indexS = planC{end};
% [xV, yV, zV] = getScanXYZVals(planC{indexS.scan}(stateS.currentScan));
[scanSet,coord] = getAxisInfo(stateS.handle.CERRAxis(1),'scanSets','coord');

[xV, yV, zV] = getScanXYZVals(planC{indexS.scan}(scanSet));
% [r, c, jnk] = xyztom(x,y,zeros(size(x)), planC);
[r, c, jnk] = xyztom(x,y,zeros(size(x)), scanSet, planC);
r = round(r);
c = round(c);
if r < 1 | r > length(yV) | c < 1 | c > length(xV)
    return;
end
hImg =  findobj(hAxis, 'tag', 'CTImage');
img = get(hImg, 'cData');
pixVal = img(r, c);
BW = roicolor(img,pixVal);
L = bwlabel(BW, 4);
region = L(r,c);
ROI = L == region;
% [contour, sliceValues] = maskToPoly(ROI, 1, planC);
% get slceValues
sliceValues = findnearest(zV,coord);
[contour, sliceValues] = maskToPoly(ROI, sliceValues, scanSet, planC);
if(length(contour.segments) > 1)
    longestDist = 0;
    longestSeg =  [];
    for i = 1:length(contour.segments)
        segmentV = contour.segments(i).points(:,1:2);
        curveLength = 0;
        for j = 1:size(segmentV,1) - 1
            curveLength = curveLength + sepsq(segmentV(j,:)', segmentV(j+1,:)');
        end
        if curveLength > longestDist
            longestDist = curveLength;
            longestSeg = i;
        end
    end
    segment = contour.segments(longestSeg).points(:,1:2);
else
    segment = contour.segments.points(:,1:2);
end
setappdata(hAxis, 'segment', segment);
drawSegment(hAxis);



%SEGMENT UNDO FUNCTIONS
function saveUndoInfo(hAxis)
%Save the current segment to the undo info list.
segment  = getappdata(hAxis, 'segment');
undoList = getappdata(hAxis, 'undoList');
if isempty(undoList)
    undoList = {};
end
undoList = {undoList{:} segment};
setappdata(hAxis, 'undoList', undoList);

function undoLast(hAxis)
%Revert segment to before the last action.
undoList = getappdata(hAxis, 'undoList');
if isempty(undoList)
    return;
end
segment = undoList{end};
undoList(end) = [];
setappdata(hAxis, 'segment', segment);
setappdata(hAxis, 'undoList', undoList);

function clearUndoInfo(hAxis)
%Clears undo info, useful if beginning new segment, or leaving draw mode.
setappdata(hAxis, 'undoList', []);


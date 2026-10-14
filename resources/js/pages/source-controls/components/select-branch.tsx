import React, { useState, useEffect } from 'react';
import { Input } from '@/components/ui/input';
import { Combobox } from '@/components/ui/combobox';
import { Button } from '@/components/ui/button';
import { RefreshCw } from 'lucide-react';

const NONE = '__none__';

interface SelectBranchProps {
  sourceControlId: string;
  repository: string;
  value: string;
  onValueChange: (value: string) => void;
  placeholder?: string;
  allowClear?: boolean;
}

export default function SelectBranch({
  sourceControlId,
  repository,
  value,
  onValueChange,
  placeholder = 'Enter branch',
  allowClear = false,
}: SelectBranchProps) {
  const [branches, setBranches] = useState<string[]>([]);
  const [gettingBranches, setGettingBranches] = useState(false);

  const refresh = async () => {
    fetchBranches(false);
  };

  const fetchBranches = async (useCache: boolean = true) => {
    setBranches([]);

    if (!sourceControlId || !repository) {
      return;
    }

    setGettingBranches(true);

    try {
      const response = await fetch(
        `/settings/source-controls/${encodeURIComponent(sourceControlId)}/branches${useCache ? '' : '/nocache'}/${encodeURIComponent(repository)}`,
      );
      const data = await response.json();
      setBranches(data);

      if (data.length === 1 && !allowClear) {
        onValueChange(data[0]);
      } else if (data.length > 0 && !data.includes(value)) {
        onValueChange('');
      }
    } catch (error) {
      console.error('Failed to fetch branches:', error);
      setBranches([]);
    } finally {
      setGettingBranches(false);
    }
  };

  useEffect(() => {
    fetchBranches();
  }, [sourceControlId, repository]);

  const comboboxItems = [
    ...(allowClear ? [{ value: NONE, label: 'None' }] : []),
    ...branches.map((branch) => ({
      value: branch,
      label: branch,
    })),
  ];

  return (
    <div className="flex items-center gap-2">
      {gettingBranches && <Input id="branch" type="text" value="" disabled={true} placeholder="Fetching..." />}
      {!gettingBranches && (branches.length === 0 || !sourceControlId || !repository) && (
        <Input id="branch" type="text" value={value ?? ''} onChange={(e) => onValueChange(e.target.value)} placeholder={placeholder} />
      )}
      {!gettingBranches && branches.length !== 0 && sourceControlId && repository && (
        <Combobox
          items={comboboxItems}
          value={value}
          placeholder={allowClear ? 'None' : ''}
          searchText="Filter branches..."
          noneFoundText="No branches found..."
          onValueChange={(selected) => onValueChange(selected === NONE ? '' : selected)}
        />
      )}
      <Button variant="outline" type="button" disabled={gettingBranches || !sourceControlId || !repository} onClick={refresh}>
        <RefreshCw className={gettingBranches ? 'animate-spin' : ''} />
      </Button>
    </div>
  );
}
